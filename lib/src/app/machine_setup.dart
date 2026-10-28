import 'dart:convert';
import 'dart:io';

import 'machines.dart';
import 'connections.dart';

import 'host_keys.dart';
import 'settings.dart';

import 'package:porelo_frontend/src/app/desk.dart';

/// An ssh key pair as text: what a person pastes, or what the wizard generates.
///
/// **The private half is a secret and this never says it**: [toString] names the public key only.
class KeyPair {
  /// Constructor taking both halves.
  const KeyPair({required this.privateKey, required this.publicKey});

  /// The private key, in OpenSSH's format.
  final String privateKey;

  /// The public key, one line: type, key, comment.
  final String publicKey;

  @override
  String toString() => 'KeyPair($publicKey)';
}

/// The steps of preparing a new machine that happen on this computer and over ssh as root: the key,
/// and whether that key logs in.
///
/// **Everything that could hold the private key is owner-only before it is written**, and nothing
/// here puts it in a command line, a log or an error.
class MachineSetup {
  /// Constructor, optionally with what runs or starts a program, whose home `~/.ssh` is in, and the desk.
  MachineSetup({
    RunWith? run,
    String? home,
    Desk? on,
    Future<Process> Function(String executable, List<String> arguments)? start,
  }) : _run = run ?? _runForReal,
       _start = start ?? Process.start,
       _desk = on ?? desk,
       _home = home ?? (on ?? desk).home;

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

  /// Lets [publicKey] — **that user's own key, never the admin's** — log in as [user], once and
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
    'BatchMode=yes',
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
      'BatchMode=yes',
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
      'ConnectTimeout=10',
      '--',
      alias,
      'umask 077 && /usr/bin/base64 -d > ${quoteForAShell(path)}',
    ]);
    final result = _resultOf(process);
    try {
      // Full blocks are divisible by three so only the final base64 block has padding.
      const blockSize = 48 * 1024;
      for (var offset = 0; offset < bytes.length; offset += blockSize) {
        final end = offset + blockSize < bytes.length ? offset + blockSize : bytes.length;
        process.stdin.write(base64Encode(bytes.sublist(offset, end)));
        await process.stdin.flush();
        onProgress?.call(end);
      }
      await process.stdin.close();
    } on Object {
      process.kill();
      await result;
      rethrow;
    }
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
        '    IdentitiesOnly yes\n';
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
      '    IdentityFile (\\S+)\n    IdentitiesOnly yes\n',
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

  /// Deletes [keyFile] and its public half — only inside `~/.ssh`, where this interface keeps them.
  Future<String> removeKey(String keyFile) async {
    if (!keyFile.startsWith('$sshDirectory/')) {
      return '$keyFile is not in ~/.ssh, so it was left where it is.';
    }
    for (final file in <File>[File(keyFile), File('$keyFile.pub')]) {
      if (file.existsSync()) file.deleteSync();
    }
    return 'Deleted $keyFile and its public half.';
  }

  /// Where the keys go.
  String get sshDirectory => '$_home/.ssh';

  /// Generates an ed25519 pair with no passphrase — the interface never asks for one — named [comment].
  Future<KeyPair> generate(String comment) => _inAPrivateDirectory((directory) async {
    final file = '${directory.path}/key';
    final made = await _run(<String>[
      openSsh('ssh-keygen', on: _desk),
      '-q',
      '-t',
      'ed25519',
      '-N',
      '',
      '-C',
      comment,
      '-f',
      file,
    ]);
    if (made.exitCode != 0) {
      throw MachineSetupFailed('ssh-keygen could not make a key: ${'${made.stderr}'.trim()}');
    }
    return KeyPair(privateKey: File(file).readAsStringSync(), publicKey: File('$file.pub').readAsStringSync().trim());
  });

  /// Why [pair]'s halves do not belong together, or null when they do.
  ///
  /// Asked of `ssh-keygen` rather than parsed here: it reads the private key and derives the public
  /// one, which is the only comparison that proves the two are a pair.
  Future<String?> mismatch(KeyPair pair) => _inAPrivateDirectory((directory) async {
    // Owner-only before it holds anything: ssh-keygen refuses a private key others could read.
    final file = File('${directory.path}/key')..createSync();
    await _keepPrivate(file.path);
    file.writeAsStringSync(_ending(pair.privateKey));
    final derived = await _run(<String>[openSsh('ssh-keygen', on: _desk), '-y', '-P', '', '-f', file.path]);
    if (derived.exitCode != 0) {
      return 'That private key cannot be read. It needs to be an OpenSSH private key with no '
          'passphrase.';
    }
    if (_keyOf('${derived.stdout}') != _keyOf(pair.publicKey)) {
      return 'The public key does not belong to that private key.';
    }
    return null;
  });

  /// Writes [pair] to `~/.ssh/<name>` and `<name>.pub`, owner-only, and answers the private key's path.
  ///
  /// **A file already there is never overwritten** unless it holds the same key, so running the
  /// wizard again is harmless and a person's other key is never lost to a name clash.
  Future<String> save(KeyPair pair, String name) async {
    final directory = Directory(sshDirectory);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      await _keepPrivate(directory.path, directory: true);
    }
    final private = File('${directory.path}/$name');
    final public = File('${private.path}.pub');
    for (final (file, content) in <(File, String)>[(private, pair.privateKey), (public, pair.publicKey)]) {
      if (file.existsSync() && file.readAsStringSync().trim() != content.trim()) {
        throw MachineSetupFailed('${file.path} already holds another key, so nothing was written.');
      }
    }
    if (!private.existsSync()) {
      private.createSync();
      await _keepPrivate(private.path);
      private.writeAsStringSync(_ending(pair.privateKey), flush: true);
    }
    if (!public.existsSync()) {
      public.writeAsStringSync('${pair.publicKey.trim()}\n', flush: true);
      if (!_desk.isWindows) await _run(<String>['chmod', '644', public.path]);
    }
    return private.path;
  }

  /// The keys a wizard kept here before, newest name first: `~/.ssh/porelo-*` without `.pub`.
  List<String> existingKeys() {
    final directory = Directory(sshDirectory);
    if (!directory.existsSync()) return const <String>[];
    return <String>[
      for (final file in directory.listSync().whereType<File>())
        if (file.uri.pathSegments.last.startsWith('porelo-') && !file.path.endsWith('.pub')) file.path,
    ]..sort();
  }

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

  /// Every private key in `~/.ssh`, by path: a file beside its `.pub`, or one that begins as a
  /// private key does. **Only the first line of a file is read**, and nothing of it is shown.
  List<String> sshKeys() {
    final directory = Directory(sshDirectory);
    if (!directory.existsSync()) return const <String>[];
    bool looksPrivate(File file) {
      RandomAccessFile? handle;
      try {
        handle = file.openSync();
        return String.fromCharCodes(handle.readSync(64)).contains('PRIVATE KEY');
      } on FileSystemException {
        return false;
      } finally {
        handle?.closeSync();
      }
    }

    return <String>[
      for (final file in directory.listSync().whereType<File>())
        if (!file.path.endsWith('.pub') && (File('${file.path}.pub').existsSync() || looksPrivate(file))) file.path,
    ]..sort();
  }

  /// The public half of the private key at [keyFile], as `ssh-keygen` derives it.
  ///
  /// `-P ''` so a key with a passphrase is refused rather than asked about: nothing here takes a
  /// passphrase, and a prompt on a terminal nobody watches would hang the wizard.
  Future<String> publicKeyOf(String keyFile) async {
    final derived = await _run(<String>[openSsh('ssh-keygen', on: _desk), '-y', '-P', '', '-f', keyFile]);
    if (derived.exitCode != 0) {
      throw MachineSetupFailed(
        '$keyFile cannot be read as a private key with no passphrase: '
        '${'${derived.stderr}'.trim()}',
      );
    }
    return '${derived.stdout}'.trim();
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
      'BatchMode=yes',
      '-o',
      'ConnectTimeout=10',
      'root@$host',
      'true',
    ]);
    if (login.exitCode == 0) return null;
    final said = '${login.stderr}'.trim();
    return said.isEmpty ? 'ssh ended with ${login.exitCode} and said nothing.' : said;
  }

  /// Runs [body] with a directory only this user can enter, removed afterwards whatever happened.
  Future<T> _inAPrivateDirectory<T>(Future<T> Function(Directory directory) body) async {
    final directory = Directory.systemTemp.createTempSync('porelo-key-');
    try {
      await _keepPrivate(directory.path, directory: true);
      return await body(directory);
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  static String _ending(String text) => text.endsWith('\n') ? text : '$text\n';

  /// The type and the key of a public key line, without its comment.
  static String _keyOf(String line) => line.trim().split(RegExp(r'\s+')).take(2).join(' ');
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
