import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/container_names.dart';

import 'e2e.dart';

/// Runs [script] on the test machine through ssh, and answers what it printed.
///
/// On standard input, never `-n`: `ssh -n` connects it to `/dev/null`, so the script would never
/// arrive and the run would say nothing and exit 0. The agent `tool/e2e.sh` raised holds the key.
///
/// A run on the test machine itself (`localhost`, as the walk in `tool/walk_idea.sh` runs) needs no
/// ssh: the account has no key for itself and knows no host key for `localhost`, so it runs here, on
/// the account's own session bus, as an ssh login would: the window's private bus of `dbus-run-session`
/// has no `systemd1`, and podman cannot place a build's container without it.
Future<String> onTheTestMachine(String script) async {
  final ssh = E2e.host == 'localhost'
      ? await Process.start('bash', <String>['-s'], environment: _theAccountsOwnBus())
      : await Process.start('ssh', <String>['-o', 'BatchMode=yes', E2e.host, 'bash -s']);
  ssh.stdin.write(script);
  await ssh.stdin.close();
  // Both at once: read one after the other, a script that writes a lot to the second would wait on
  // a full pipe that nobody reads.
  final (out, err) = await (
    ssh.stdout.transform(const SystemEncoding().decoder).join(),
    ssh.stderr.transform(const SystemEncoding().decoder).join(),
  ).wait;
  final code = await ssh.exitCode;
  if (code != 0) throw StateError('on the test machine, exit $code: $err');
  return out.trim();
}

Map<String, String> _theAccountsOwnBus() {
  final runtime = Platform.environment['XDG_RUNTIME_DIR'];
  if (runtime == null || runtime.isEmpty) throw StateError('on the test machine, XDG_RUNTIME_DIR is not set');
  return <String, String>{'DBUS_SESSION_BUS_ADDRESS': 'unix:path=$runtime/bus'};
}

/// A shell function for a script on the test machine: `unpack_porelo <package> <dir>` unpacks the
/// newest published `<package>` of Porelo's snapshots into `<dir>`, unprivileged, never over what is
/// installed. A machine with `dpkg-deb` takes the `.deb` from `porelo-dist-deb`'s index, checked
/// against the digest the index publishes; a machine with `rpm` takes the `.rpm` through its own
/// Porelo source with `dnf download --refresh`, which checks it against that source's metadata.
const unpackPorelo = r'''
unpack_porelo() {
  _w=$(mktemp -d)
  if command -v dpkg-deb >/dev/null 2>&1; then
    _repo=https://fuinorg.jfrog.io/artifactory/porelo-dist-deb
    # The newest version's file and digest, as the index published them, split into two arguments.
    # shellcheck disable=SC2046
    set -- "$1" "$2" $(curl -fsSL "$_repo/dists/snapshots/main/binary-amd64/Packages" |
      awk -v p="$1" '$0 == "Package: " p {x = 1} x && /^Version:/ {v = $2} x && /^Filename:/ {f = $2}
        x && /^SHA256:/ {h = $2} /^$/ {if (x) print v, f, h; x = 0} END {if (x) print v, f, h}' |
      sort -V | tail -1 | cut -d' ' -f2-)
    [ -n "${3:-}" ] || { echo "$1 is not in the index" >&2; rm -rf "$_w"; return 1; }
    curl -fsSL -o "$_w/p.deb" "$_repo/$3"
    echo "$4  $_w/p.deb" | sha256sum -c --quiet -
    dpkg-deb -x "$_w/p.deb" "$2"
  else
    (cd "$_w" && dnf download --refresh --quiet "$1" >/dev/null)
    set -- "$1" "$2" "$_w/$1"-[0-9]*.rpm
    [ -f "$3" ] || { echo "$1 could not be downloaded from this machine's Porelo source" >&2; rm -rf "$_w"; return 1; }
    mkdir -p "$2"
    (cd "$2" && rpm2cpio "$3" | cpio -idm --quiet)
  fi
  rm -rf "$_w"
}
''';

/// Where the scenario's repository was made on the test machine, once it was.
String? theRepository;

/// Where the key the test machine's account has is, once a step has made sure of one.
String? theKey;

/// The machine's own sentence from the connection wizard's check, read before it was left.
String? theCheckSaid;

/// The vault entry a scenario copied a key into, once the machine listed it.
String? theVaultEntry;

/// The file name of the message a scenario had held for a person on the test machine.
String? theHeldMessage;

/// What the interface showed as that message's text.
String? theMessageRead;

/// Removes what a step made on the test machine **when the scenario ends, passed or failed**:
/// [remove] runs then, whatever came before it, and [leftOver] after it must print none of [names],
/// or the scenario fails naming what it left. A scenario's own last step removes the same and checks
/// it; this is for one that went red before it got there.
void removeAfterwards({required String remove, required String leftOver, required List<String> names}) =>
    addTearDown(() async {
      await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"\n$remove');
      final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"\n$leftOver');
      final still = <String>[
        for (final name in names)
          if (left.contains(name)) name,
      ];
      if (still.isNotEmpty) throw StateError('left on the test machine: ${still.join(', ')}');
    });

/// The container Porelo makes for a new task [task] of [project]: `porelo_<task>` in project `porelo`, otherwise
/// `porelo-<project>_<task>`. The test projects set no short spelling.
String containerOf(String project, String task) => newContainerName(project, task);

/// The names the container of task [task] of [project] may have: the one Porelo gives a new task, and the one a task
/// made by an older Porelo keeps, `porelo-<task>` in project `porelo` and `porelo-<project>-<task>` otherwise.
List<String> containersOf(String project, String task) => <String>[
  containerOf(project, task),
  project == 'porelo' ? 'porelo-$task' : 'porelo-$project-$task',
];

/// What stops and removes a task under every name in [containers], tolerating each name no task has; whoever needs
/// them gone checks the list afterwards.
String stoppingAndRemoving(List<String> containers, {bool force = true}) => <String>[
  for (final container in containers)
    'porelo task stop "$container" >/dev/null 2>&1 || true\n'
        'porelo task remove${force ? ' --force' : ''} "$container" >/dev/null 2>&1 || true\n',
].join();

/// What removes a task and its project, whichever is still there: tolerant, since the scenario's own
/// step may have removed them already.
String removingTheWork(String task, String project) =>
    '''
porelo task stop "$task" >/dev/null 2>&1 || true
porelo task remove --force "$task" >/dev/null 2>&1 || true
porelo project remove "$project" >/dev/null 2>&1 || true
${removingTheProjectFiles(project)}
''';

/// What registers the project [name] on this account alone: [file], in the place Porelo reads such a project from.
/// The heredoc is unquoted, so a shell variable in [file] is expanded.
String writingTheProjectFile(String name, String file) =>
    '''
mkdir -p "\${XDG_CONFIG_HOME:-\$HOME/.config}/porelo/projects/$name"
cat > "\${XDG_CONFIG_HOME:-\$HOME/.config}/porelo/projects/$name/project.yml" <<YAML
$file
YAML
''';

/// What removes what a scenario wrote for the project [name], once `porelo project remove` has taken it away.
String removingTheProjectFiles(String name) =>
    'rm -rf "\${XDG_CONFIG_HOME:-\$HOME/.config}/porelo/projects/$name" "\$HOME/$name-backend.git"';

/// What [removeAfterwards] reads to say what is left of work: every task and every project.
const listingTheWork = 'porelo task list 2>/dev/null; porelo project list 2>/dev/null; ls "\$HOME"';
