// Linux: HostRun uses chmod.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import '../bin/porelo_host.dart' show runHostCommand;
import 'host_run_test.dart' show ScriptedRemote;
import 'server_contract_test.dart' show sshKey;

/// The identity's own ed25519 host key, other than the one the person gave for the first login.
const _identityKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

const _place = '/etc/porelo-host/setup/identity.json';

/// What only the folder check before the identity's write holds.
const _folderCheck = 'test ! -L /etc/porelo-host/setup';

/// A host's identity as the vault hands it on; the private halves are stand-ins whose words a test looks for.
Map<String, Object?> _identity({String host = 'orchard', List<Map<String, Object?>>? sshHostKeys}) => {
  'host': host,
  'organization': {
    'public': 'ssh-ed25519 AAAAorganization porelo',
    'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-ORGANIZATION\n-----END OPENSSH PRIVATE KEY-----\n',
  },
  'repositories': [
    {
      'project': 'garden',
      'repository': 'acme/garden',
      'address': 'https://forge.example/acme/garden.git',
      'key_id': 7,
      'title': 'porelo host orchard project garden',
      'public': 'ssh-ed25519 AAAArepository porelo',
      'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-REPOSITORY\n-----END OPENSSH PRIVATE KEY-----\n',
    },
  ],
  'ssh_host_keys':
      sshHostKeys ??
      [
        {
          'type': 'ed25519',
          'public': '$_identityKey root@orchard',
          'private': '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-HOST\n-----END OPENSSH PRIVATE KEY-----\n',
        },
      ],
};

/// A host that refuses every command holding [failing], and answers the rest as [ScriptedRemote] does.
class _Refusing extends ScriptedRemote {
  _Refusing(super.lines, {this.failing});

  final String? failing;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    final answered = await super.run(host, user, command, input: input, onLine: onLine);
    if (failing case final part? when command.contains(part)) return const RemoteResult(1, 'refused here');
    return answered;
  }
}

void main() {
  late Directory scratch;
  late File collection;
  late File machineFile;
  late StringBuffer output;
  late StringBuffer errors;
  late List<(String, String)> pins;

  List<String> record(String key) => [
    jsonEncode({'v': 1, 'state': 'ok', 'task': 'finished', 'text': 'Host ready'}),
    jsonEncode({
      'v': 1,
      'state': 'host',
      'host': {
        'address': '192.0.2.7',
        'ssh_host_key': key,
        'homeserver': 'orchard',
        'services': {
          'forge': {'web_port': 3000, 'git_port': 3001},
        },
      },
    }),
  ];

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('carried-identity-');
    collection = File('${scratch.path}/collection.tar.gz');
    await collection.writeAsBytes([0, 128, 255, 10]);
    machineFile = await File('${scratch.path}/machine.yml').writeAsString('organization:\n  pin: "hank key\\n"\n');
    output = StringBuffer();
    errors = StringBuffer();
    pins = [];
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<int> up(
    ScriptedRemote remote, {
    List<String> verb = const ['up'],
    String? identity,
    bool given = true,
    bool flag = true,
  }) async => runHostCommand(
    [
      ...verb,
      '--public-key',
      sshKey,
      if (given) ...['--given', '192.0.2.7', '--host-key', sshKey] else ...['--scaleway-project', 'p'],
      '--host-name',
      'orchard',
      '--forge-runner-capacity',
      '1',
      '--forge-job-cpus',
      '1',
      '--forge-job-memory',
      '768m',
      '--collection',
      collection.path,
      '--collection-sha256',
      sha256.convert(await collection.readAsBytes()).toString(),
      '--machine-file',
      machineFile.path,
      if (flag) '--identity-stdin',
    ],
    remote: remote,
    trust: (address, key) async => pins.add((address, key)),
    identityInput: Stream.value(utf8.encode(identity ?? jsonEncode(_identity()))),
    output: output,
    errors: errors,
    environment: {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path},
  );

  List<Step> steps() => LineSplitter.split('$output').map(Step.fromLine).whereType<Step>().toList();

  // Harm: an identity piped into a run that never reads it, or into one that gives a server back, is lost or misread.
  test('--identity-stdin is refused outside up --given', () async {
    final remote = ScriptedRemote(record(_identityKey));
    expect(await up(remote, given: false), Exit.usage);
    expect(await up(remote, verb: const ['down']), Exit.usage);
    expect(remote.commands, isEmpty);
  });

  // Harm: a host is set up with another host's keys, without the host key that pins it, or with a control character
  // that a terminal or a log reads as a command; or more than the vault could ever hold fills the host's disk.
  for (final (name, identity) in <(String, String)>[
    ('more than 256 KiB', jsonEncode({..._identity(), 'padding': 'x' * (256 * 1024)})),
    ('another host', jsonEncode(_identity(host: 'lemon'))),
    (
      'no ed25519 host key',
      jsonEncode(
        _identity(
          sshHostKeys: [
            {'type': 'rsa', 'public': 'ssh-rsa AAAArsa root@orchard', 'private': 'x'},
          ],
        ),
      ),
    ),
    (
      'a bad ed25519 host key',
      jsonEncode(
        _identity(
          sshHostKeys: [
            {'type': 'ed25519', 'public': 'ssh-ed25519 not-a-key', 'private': 'x'},
          ],
        ),
      ),
    ),
    (
      'a control character',
      jsonEncode({
        ..._identity(),
        'organization': {'public': 'ssh-ed25519 AAAA\u001b[2Jorganization', 'private': 'x'},
      }),
    ),
    ('no JSON object', '[]'),
  ]) {
    test('an identity with $name is refused before any connection', () async {
      final remote = ScriptedRemote(record(_identityKey));
      expect(await up(remote, identity: identity), Exit.refused);
      expect(remote.commands, isEmpty);
      expect('$output$errors', isNot(contains('SECRET')));
    });
  }

  // Harm: the identity lies in a file on this computer or another account's reach on the host, or arrives changed.
  test('the identity is streamed into a checked root-only folder, and the record with its key re-pins', () async {
    final remote = ScriptedRemote(record(_identityKey));
    expect(await up(remote), Exit.done, reason: '$output $errors');
    final send = remote.runs.singleWhere((run) => run.command.contains('file=$_place'));
    expect(send.input, jsonEncode(_identity()));
    expect(send.command, contains('umask 077'));
    expect(send.command, contains("stat -c '%u:%a'"));
    expect(send.command, contains('sha256sum'));
    expect(send.command, contains(sha256.convert(utf8.encode(jsonEncode(_identity()))).toString()));
    expect(
      remote.commands.where((command) => command.startsWith('copy ') && command.contains('identity.json')),
      isEmpty,
    );
    expect(remote.commands.where((command) => command.contains('rm -f $_place')), isEmpty);
    expect(pins, [('192.0.2.7', sshKey), ('192.0.2.7', _identityKey)], reason: 'the given key first, then its own');
    expect('$output$errors', isNot(contains('SECRET')));
  });

  // Harm: the host's script for the identity breaks, so no host is set up with one; or a changed identity is taken.
  test("the identity's script writes exactly what was sent, root's alone, and refuses what does not match", () async {
    final remote = ScriptedRemote(record(_identityKey));
    expect(await up(remote), Exit.done, reason: '$output $errors');
    final send = remote.runs.singleWhere((run) => run.command.contains('file=$_place'));
    final check = remote.runs.singleWhere((run) => run.command.contains(_folderCheck));
    final place = '${scratch.path}/etc/porelo-host/setup';
    // Root's ownership is the stand-in; the folder, the file and its mode are real.
    String here(String command) => command.replaceAll('/etc/porelo-host', '${scratch.path}/etc/porelo-host');
    final script = '${here(check.command)}\n${here(send.command)}';
    const stubs =
        'chown() { :; }\nstat() { printf "0:%s" "\$(command stat -c %a "\$3")"; }\n'
        'install() { if [ "\$1" = -d ]; then mkdir -p "\${@: -1}"; chmod "\$7" "\${@: -1}"; fi; }\n';
    Future<ProcessResult> run(String input) async {
      final process = await Process.start('bash', ['-c', '$stubs$script']);
      process.stdin.write(input);
      await process.stdin.close();
      final code = await process.exitCode;
      return ProcessResult(process.pid, code, '', '');
    }

    expect((await run(send.input)).exitCode, 0);
    final written = File('$place/identity.json');
    expect(await written.readAsString(), send.input);
    expect((await written.stat()).modeString(), 'rw-------');
    expect((await run('${send.input} ')).exitCode, isNot(0), reason: 'what arrived is not what was sent');

    // A setup folder that is a link elsewhere is refused before anything is made or written through it.
    await Directory(place).delete(recursive: true);
    final elsewhere = await Directory('${scratch.path}/elsewhere').create();
    await Link(place).create(elsewhere.path);
    expect((await run(send.input)).exitCode, isNot(0));
    expect(elsewhere.listSync(), isEmpty);
    final cleanup = remote.runs.where((run) => run.command.contains('rm -f $_place')).toList();
    expect(cleanup, isEmpty, reason: 'nothing to remove after a run that finished');
  });

  // Harm: the identity, or a removal of it, goes through a link another account placed, to wherever it points.
  test('a setup folder that is not root-only refuses before anything is written, and nothing is removed', () async {
    final remote = _Refusing(record(_identityKey), failing: _folderCheck);
    expect(await up(remote), Exit.refused);
    expect(remote.commands.where((command) => command.contains('file=$_place')), isEmpty);
    expect(
      remote.commands.where((command) => command.contains('/etc/porelo-host/setup/machine.yml')),
      isEmpty,
      reason: 'nor the machine file',
    );
    expect(remote.commands.where((command) => command.contains('rm -f $_place')), isEmpty);
  });

  // Harm: a run that stopped leaves the host's private keys on it, and nobody is told.
  test('a removal that fails after a stop is said, without any key', () async {
    final remote = _Refusing(record(_identityKey), failing: 'rm -f $_place');
    remote.playExit = 1;
    expect(await up(remote), isNot(Exit.done));
    final notes = steps().where((step) => step.state == StepState.note).toList();
    expect(notes.single.words, contains('may still lie in $_place'));
    expect('$output$errors', isNot(contains('SECRET')));
  });

  // Harm: a host that kept its old key, or another machine, is taken for the one set up with the identity.
  test('a record with the given key while an identity was sent refuses, and nothing is re-pinned', () async {
    final remote = ScriptedRemote(record(sshKey));
    expect(await up(remote), Exit.refused);
    expect(steps().where((step) => step.state == StepState.host), isEmpty);
    expect(pins, [('192.0.2.7', sshKey)], reason: 'the given key for the first login alone');
    expect(remote.commands.where((command) => command.contains('rm -f $_place')), hasLength(1));
  });

  // Harm: a run that stopped leaves the host's private keys in a file on it.
  for (final (where, failing) in <(String, String?)>[
    ('the copy', 'file=$_place'),
    ('the Ansible install', 'ansible-galaxy'),
    ('the play', null),
  ]) {
    test('the identity is removed once after a failure at $where', () async {
      final remote = _Refusing(record(_identityKey), failing: failing);
      if (failing == null) remote.playExit = 1;
      expect(await up(remote), isNot(Exit.done));
      expect(remote.commands.where((command) => command.contains('rm -f $_place')), hasLength(1));
      expect(pins, [('192.0.2.7', sshKey)]);
      expect('$output$errors', isNot(contains('SECRET')));
    });
  }

  // Harm: a first setup, with no identity kept, is held to an identity's key, or changes as one with an identity.
  test('without --identity-stdin nothing is sent and the given key stays pinned', () async {
    final remote = ScriptedRemote(record(sshKey));
    expect(await up(remote, flag: false), Exit.done, reason: '$output $errors');
    expect(remote.commands.where((command) => command.contains(_place)), isEmpty);
    expect(pins, [('192.0.2.7', sshKey)]);
  });
}
