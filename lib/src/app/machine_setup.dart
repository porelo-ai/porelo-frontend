import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart' show checkedEd25519;

import 'machines.dart';
import 'connections.dart';

import 'host_keys.dart';
import 'settings.dart';

import 'package:porelo_frontend/src/app/desk.dart';

/// The current person's public identity selected by Core for their local SSH agent.
class PersonAgentIdentity {
  /// Holds a public key and its public identity file; no private key is imported.
  const PersonAgentIdentity({required this.publicKey, required this.publicFile});

  /// The person's public Ed25519 key.
  final String publicKey;

  /// The public identity reference used to select the key in the agent.
  final String publicFile;
}

/// Prepares a machine over SSH with the current person’s identity selected through their agent.
class MachineSetup {
  /// Constructor, optionally with what runs or starts a program, whose home `~/.ssh` is in, and the desk.
  MachineSetup({
    this.personIdentity,
    RunWith? run,
    String? home,
    Desk? on,
    Future<Process> Function(String executable, List<String> arguments)? start,
  }) : _run = run ?? _runForReal,
       _start = start ?? Process.start,
       _desk = on ?? desk,
       _home = home ?? (on ?? desk).home;

  /// The verified person identity boundary, absent until Core supplies it.
  final Future<PersonAgentIdentity> Function()? personIdentity;

  /// Reads the current identity without generating or importing private keys.
  Future<PersonAgentIdentity> identityFromAgent() async {
    final PersonAgentIdentity? identity;
    try {
      identity = await personIdentity?.call();
    } on Exception {
      throw const MachineSetupFailed(
        'The verified person identity could not be read. Unlock your key and refresh Core identity.',
      );
    }
    if (identity == null ||
        !identity.publicFile.startsWith('/') ||
        RegExp(r'[\r\n\x00]').hasMatch(identity.publicFile)) {
      throw const MachineSetupFailed(
        'The verified person identity is not available. Unlock your key and refresh Core identity.',
      );
    }
    try {
      checkedEd25519(identity.publicKey);
    } on FormatException {
      throw const MachineSetupFailed('Core did not supply a valid public identity.');
    }
    return identity;
  }

  final RunWith _run;
  final Future<Process> Function(String executable, List<String> arguments) _start;
  final Desk _desk;
  final String _home;

  /// Keeps [path] to its owner, through [_run] so a test sees it.
  Future<void> _keepPrivate(String path, {bool directory = false}) async {
    final command = _desk.privateCommand(path, directory: directory);
    if (command != null) await _run(command);
  }

  static Future<ProcessResult> _runForReal(List<String> command, {String? input}) async {
    if (input == null) return Process.run(command.first, command.sublist(1));
    final process = await Process.start(command.first, command.sublist(1));
    process.stdin.write(input);
    await process.stdin.close();
    final out = process.stdout.transform(const SystemEncoding().decoder).join();
    final err = process.stderr.transform(const SystemEncoding().decoder).join();
    return ProcessResult(process.pid, await process.exitCode, await out, await err);
  }

  /// Where Porelo publishes its setup script, for a machine that has nothing installed yet.
  static const String setupScript = 'https://fuinorg.jfrog.io/artifactory/porelo-dist-deb/setup/porelo-setup-latest.sh';

  /// Fetches Porelo's setup script onto the machine, where every later step runs it from. It lands
  /// in root's own directory and replaces the old one whole, so nothing but root changes it there,
  /// and it says the SHA-256 of what it fetched: [prepare] runs it only while it is still that.
  static String _fetch() =>
      '''set -e
f=/root/porelo-setup.sh
t=\$(mktemp /root/porelo-setup.XXXXXX)
if command -v curl >/dev/null 2>&1; then curl -fsSL -o "\$t" '$setupScript'
else wget -qO "\$t" '$setupScript'; fi
mv -f "\$t" "\$f"
printf 'The script shown has the SHA-256 %s.\\n' "\$(sha256sum "\$f" | cut -d' ' -f1)"
''';

  /// The SHA-256 [show]'s output says the fetched script has, or null where it says none.
  static String? digestIn(String shown) =>
      RegExp(r'The script shown has the SHA-256 ([0-9a-f]{64})\.').firstMatch(shown)?.group(1);

  /// What [prepare] ends with when the script on the machine is no longer the one shown.
  static const int notTheScriptShown = 97;

  /// Fetches the script and asks it what this machine could install, installing nothing: the
  /// machine's own package source is the catalog, never this interface — Porelo's answer,
  /// since a client that named a repository would name one the machine does not trust.
  static String listInstallable() => '${_fetch()}bash "\$f" --list --json\n';

  /// Prints every command the setup script would run for [user] and the chosen [packages],
  /// running none. **What the person reads is the script's own `--show`**, not a summary written
  /// here.
  static String show(String user, Iterable<String> packages) =>
      '${_fetch()}bash "\$f" ${_arguments(user, packages)} --show\n';

  /// Runs the setup script fetched by [show]: it creates [user] and installs Porelo and [packages].
  /// **Exactly the bytes shown run**: the script is checked against the SHA-256 [show] said, and
  /// nothing runs where it differs.
  static String prepare(String user, Iterable<String> packages, {required String digest}) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw const MachineSetupFailed('What the setup script would do has to be shown first.');
    }
    return "printf '%s  %s\\n' '$digest' /root/porelo-setup.sh | sha256sum -c --status"
        " || { echo 'The setup script on the machine is not the one shown.' >&2; exit $notTheScriptShown; }\n"
        'bash /root/porelo-setup.sh ${_arguments(user, packages)}\n';
  }

  /// The script's arguments, each checked and quoted for a shell, so nothing but a user and package
  /// names reaches root's command line, whatever a kept draft held.
  static String _arguments(String user, Iterable<String> packages) {
    if (!Settings.isUserName(user)) throw MachineSetupFailed('"$user" cannot be a user name.');
    for (final each in packages) {
      if (!isPackageName(each)) throw MachineSetupFailed('"$each" cannot be a package name.');
    }
    return <String>[
      '--user ${quoteForAShell(user)}',
      for (final each in packages) '--with ${quoteForAShell(each)}',
    ].join(' ');
  }

  /// What `--list --json` answered: one entry per package this machine could have.
  static List<InstallablePackage> installableIn(String json) {
    final decoded = jsonDecode(json);
    final packages = decoded is Map ? decoded['packages'] : null;
    if (packages is! List) {
      throw const MachineSetupFailed('The setup script answered its list in a shape this build does not read.');
    }
    return <InstallablePackage>[
      for (final each in packages)
        if (each is Map && each['name'] is String && isPackageName(each['name'] as String))
          InstallablePackage(
            name: each['name'] as String,
            kind: each['kind'] is String ? each['kind'] as String : '',
            description: each['description'] is String ? each['description'] as String : '',
            installed: each['installed'] == true,
            version: each['version'] is String ? each['version'] as String : '',
          ),
    ];
  }

  /// Whether [name] can be a package name, so nothing else reaches a root command line.
  static bool isPackageName(String name) => RegExp(r'^[a-z0-9][a-z0-9+.-]*$').hasMatch(name);

  /// Lets the current person’s [publicKey] log in as [user], once and
  /// owner-only, and lets [user] log in with a key and nothing else: its password stays locked, and
  /// sshd is told so for that user alone. The rule ends with `Match all`, so it cannot reach into
  /// the rest of sshd's configuration, and sshd checks it before it is loaded: a rule it refuses is
  /// taken out again rather than left to lock anybody out.
  static String authorize(String user, String publicKey) =>
      '''set -e
user=${quoteForAShell(user)}
key=${quoteForAShell(publicKey)}
home=\$(getent passwd "\$user" | cut -d: -f6)
install -d -m 700 -o "\$user" -g "\$user" "\$home/.ssh"
touch "\$home/.ssh/authorized_keys"
chown "\$user:\$user" "\$home/.ssh/authorized_keys"
chmod 600 "\$home/.ssh/authorized_keys"
grep -qxF "\$key" "\$home/.ssh/authorized_keys" || printf '%s\\n' "\$key" >> "\$home/.ssh/authorized_keys"
passwd -l "\$user" >/dev/null
mkdir -p /etc/ssh/sshd_config.d
rule="/etc/ssh/sshd_config.d/20-porelo-\$user.conf"
printf 'Match User %s\\n    AuthenticationMethods publickey\\n    PasswordAuthentication no\\n    KbdInteractiveAuthentication no\\nMatch all\\n' "\$user" > "\$rule"
if ! sshd -t; then rm -f "\$rule"; echo "sshd refused the rule for \$user, so it was taken out again" >&2; exit 1; fi
systemctl reload ssh 2>/dev/null || systemctl reload sshd
''';

  /// Turns off logging in as root and with a password, once the work user has logged in.
  static const String harden = '''set -e
printf 'PermitRootLogin no\\nPasswordAuthentication no\\n' > /etc/ssh/sshd_config.d/10-porelo.conf
systemctl reload ssh 2>/dev/null || systemctl reload sshd
''';

  /// What each exit of the setup script means, as Porelo promises them.
  static String whatTheScriptSaid(int exitCode) => switch (exitCode) {
    0 => 'The machine is prepared.',
    2 => 'The setup script did not understand what it was asked.',
    3 => 'The setup script does not know this operating system, so nothing was installed.',
    4 => 'The setup script did not run as root.',
    5 => 'A check failed and the machine is not usable yet; what it said is above.',
    notTheScriptShown =>
      'The setup script on the machine changed after it was shown, so nothing ran. '
          'Show it again.',
    _ => 'The setup script ended with $exitCode.',
  };

  /// Runs [script] as root on [host] with the key at [keyFile], on standard input: nothing of it
  /// is in a command line, and it is exactly the text that was shown.
  Future<ProcessResult> asRoot(String host, String keyFile, String script) => _run(<String>[
    openSsh('ssh', on: _desk),
    '-i',
    keyFile,
    '-o',
    'IdentitiesOnly=yes',
    '-o',
    'ForwardAgent=no',
    '-o',
    'BatchMode=yes',
    '-o',
    'ForwardAgent=no',
    '-o',
    'ConnectTimeout=10',
    'root@$host',
    'bash',
    '-s',
  ], input: script);

  /// [asRoot], with every line handed to [onLine] as it arrives, so a person watching a script that
  /// takes minutes sees it working rather than a window that looks stuck.
  Future<ProcessResult> asRootLive(
    String host,
    String keyFile,
    String script,
    void Function(String line) onLine,
  ) async {
    final process = await _start(openSsh('ssh', on: _desk), <String>[
      '-i',
      keyFile,
      '-o',
      'IdentitiesOnly=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'ConnectTimeout=10',
      'root@$host',
      'bash',
      '-s',
    ]);
    final result = _resultOf(process, onLine: onLine);
    process.stdin.write(script);
    await process.stdin.close();
    return result;
  }

  static Future<ProcessResult> _resultOf(Process process, {void Function(String)? onLine}) async {
    final out = StringBuffer();
    final err = StringBuffer();
    Future<void> follow(Stream<List<int>> stream, StringBuffer into) =>
        stream.transform(const SystemEncoding().decoder).transform(const LineSplitter()).forEach((line) {
          into.writeln(line);
          onLine?.call(line);
        });
    await Future.wait(<Future<void>>[follow(process.stdout, out), follow(process.stderr, err)]);
    return ProcessResult(process.pid, await process.exitCode, '$out', '$err');
  }

  /// Runs [command] as the work user through the `Host` entry [alias].
  Future<ProcessResult> asUser(String alias, String command) => _run(<String>[
    openSsh('ssh', on: _desk),
    '-n',
    '-o',
    'BatchMode=yes',
    '-o',
    'ForwardAgent=no',
    '-o',
    'ConnectTimeout=10',
    '--',
    alias,
    command,
  ]);

  /// [asUser], with output followed while the command runs, including its change of phase.
  Future<ProcessResult> asUserLive(String alias, String command, void Function(String) onLine) async {
    final process = await _start(openSsh('ssh', on: _desk), <String>[
      '-n',
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'ConnectTimeout=10',
      '--',
      alias,
      command,
    ]);
    return _resultOf(process, onLine: onLine);
  }

  /// Writes [bytes] to [path] as the work user, through the `Host` entry [alias]: base64 on standard input, decoded
  /// there into a file only that user reads. [onProgress] counts source bytes flushed to ssh's pipe.
  Future<ProcessResult> sendToUser(String alias, String path, List<int> bytes, {void Function(int)? onProgress}) async {
    final process = await _start(openSsh('ssh', on: _desk), <String>[
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'ConnectTimeout=10',
      '--',
      alias,
      'umask 077 && /usr/bin/base64 -d > ${quoteForAShell(path)}',
    ]);
    final result = _resultOf(process);
    // An ssh that ended early closes the pipe: its exit and its words say why, never the write that found it closed.
    var broken = false;
    unawaited(process.stdin.done.then<void>((_) {}, onError: (Object _) => broken = true));
    try {
      // Full blocks are divisible by three so only the final base64 block has padding.
      const blockSize = 48 * 1024;
      for (var offset = 0; offset < bytes.length && !broken; offset += blockSize) {
        final end = offset + blockSize < bytes.length ? offset + blockSize : bytes.length;
        process.stdin.write(base64Encode(bytes.sublist(offset, end)));
        await process.stdin.flush();
        onProgress?.call(end);
      }
      await process.stdin.close();
    } on Object {
      broken = true;
    }
    if (broken) process.kill();
    return result;
  }

  /// Adds a `Host` entry for the machine to `~/.ssh/config`: **as the work user, never root**.
  ///
  /// Appended, after a copy of the file is kept; an entry of that name that already says the same
  /// is left alone, and one that says something else is never overwritten.
  Future<String> addHostEntry({
    required String alias,
    required String host,
    required String user,
    required String keyFile,
  }) async {
    final entry =
        'Host $alias\n'
        '    HostName $host\n'
        '    User $user\n'
        '    IdentityFile $keyFile\n'
        '    IdentitiesOnly yes\n'
        '    ForwardAgent no\n';
    final directory = Directory(sshDirectory);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      await _keepPrivate(directory.path, directory: true);
    }
    final config = File('${directory.path}/config');
    final before = config.existsSync() ? config.readAsStringSync() : '';
    if (before.contains(entry)) return '~/.ssh/config already has $alias.';
    if (RegExp('^Host\\s+${RegExp.escape(alias)}\\s*\$', multiLine: true).hasMatch(before)) {
      throw MachineSetupFailed(
        '~/.ssh/config already has a Host $alias that says something else, so nothing was written.',
      );
    }
    if (before.isNotEmpty) {
      final kept = '${config.path}.before-$alias';
      File(kept).writeAsStringSync(before);
      await _keepPrivate(kept);
    } else {
      config.createSync();
    }
    await _keepPrivate(config.path);
    final separator = before.isEmpty || before.endsWith('\n\n') ? '' : (before.endsWith('\n') ? '\n' : '\n\n');
    config.writeAsStringSync('$separator$entry', mode: FileMode.append, flush: true);
    return 'Added Host $alias to ~/.ssh/config.';
  }

  /// The `Host` entry this interface wrote for [alias], and the key it names — or null when
  /// `~/.ssh/config` holds none **in exactly the form [addHostEntry] writes**. An entry somebody
  /// wrote by hand, or changed since, is theirs, and is never offered for removal.
  ({String entry, String keyFile})? entryWrittenFor(String alias) {
    final config = File('$sshDirectory/config');
    if (!config.existsSync()) return null;
    final written = RegExp(
      '^Host ${RegExp.escape(alias)}\n    HostName \\S+\n    User \\S+\n'
      '    IdentityFile (\\S+)\n    IdentitiesOnly yes\n(?:    ForwardAgent no\n)?',
      multiLine: true,
    ).firstMatch(config.readAsStringSync());
    return written == null ? null : (entry: written.group(0)!, keyFile: written.group(1)!);
  }

  /// Whether a `Host` entry other than [alias]'s names [keyFile], so deleting it would break that.
  bool keyUsedElsewhere(String keyFile, String alias) {
    final config = File('$sshDirectory/config');
    if (!config.existsSync()) return false;
    final others = config.readAsStringSync().replaceFirst(entryWrittenFor(alias)?.entry ?? '', '');
    return RegExp('^\\s*IdentityFile\\s+${RegExp.escape(keyFile)}\\s*\$', multiLine: true).hasMatch(others);
  }

  /// Takes the entry [addHostEntry] wrote for [alias] out of `~/.ssh/config`, and nothing else.
  ///
  /// The file as it was is kept beside it first, owner-only, as when the entry was added.
  Future<String> removeHostEntry(String alias) async {
    final written = entryWrittenFor(alias);
    if (written == null) return '~/.ssh/config has no Host $alias written here, so nothing was changed.';
    final config = File('$sshDirectory/config');
    final before = config.readAsStringSync();
    final kept = '${config.path}.before-forgetting-$alias';
    File(kept).writeAsStringSync(before);
    await _keepPrivate(kept);
    final after = before.replaceFirst(written.entry, '').replaceAll(RegExp('\n{3,}'), '\n\n');
    config.writeAsStringSync(after.trim().isEmpty ? '' : after, flush: true);
    await _keepPrivate(config.path);
    return 'Removed Host $alias from ~/.ssh/config; the file as it was is kept as ${kept.split('/').last}.';
  }

  /// The directory containing the person's SSH configuration.
  String get sshDirectory => '$_home/.ssh';

  /// Runs [command] — the machine's own, as Porelo named it — with [value] on its standard input, and
  /// answers null when it worked or what it said when it did not.
  ///
  /// **The value is on standard input and nowhere else**: never an argument, never a file here. It
  /// is what an ssh key needs, because a key is a file and the machine's prompt reads one line.
  Future<String?> storeOnTheMachine(List<String> command, String value) async {
    final result = await _run(command, input: value);
    if (result.exitCode == 0) return null;
    final said = '${result.stderr}'.trim();
    return said.isEmpty ? 'It ended with exit code ${result.exitCode}.' : said;
  }

  /// Why logging in as root on [host] with the key at [keyFile] failed, or null when it worked.
  Future<String?> loginAsRoot(String host, String keyFile) async {
    final login = await _run(<String>[
      openSsh('ssh', on: _desk),
      '-i',
      keyFile,
      '-o',
      'IdentitiesOnly=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      '-o',
      'ConnectTimeout=10',
      'root@$host',
      'true',
    ]);
    if (login.exitCode == 0) return null;
    final said = '${login.stderr}'.trim();
    return said.isEmpty ? 'ssh ended with ${login.exitCode} and said nothing.' : said;
  }
}

/// A step of preparing a machine failed, in words that say which.
class MachineSetupFailed implements Exception {
  /// Constructor taking what went wrong.
  const MachineSetupFailed(this.message);

  /// What went wrong, never quoting a private key.
  final String message;

  @override
  String toString() => message;
}

/// A package a machine could have, as its setup script lists it.
class InstallablePackage {
  /// Constructor taking what the list says.
  const InstallablePackage({
    required this.name,
    required this.kind,
    required this.description,
    required this.installed,
    required this.version,
  });

  /// The real package name, never a virtual one.
  final String name;

  /// `agent` or `transport`, or whatever a newer script names.
  final String kind;

  /// One line saying what it is.
  final String description;

  /// Whether the machine has it already.
  final bool installed;

  /// The version the index offers, or empty.
  final String version;
}
