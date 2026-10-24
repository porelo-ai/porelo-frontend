import 'dart:io';

import 'package:porelo_frontend/src/app/desk.dart';

import 'machines.dart';

/// Runs a program and answers what it printed, the way [Process.run] does, with optional input.
typedef RunWith = Future<ProcessResult> Function(List<String> command, {String? input});

/// What is known about a machine's host key before anything logs in.
class HostKeyCheck {
  /// Constructor taking what was found.
  const HostKeyCheck({
    required this.destination,
    required this.host,
    required this.known,
    this.scanned = const <String>[],
    this.fingerprints = const <String>[],
    this.problem,
    this.changed = false,
    this.knownIn = const <String>[],
    this.writeTo = '',
    this.pinnedByHost = false,
  });

  /// What was asked about: `user@host`, a host, or an alias from `~/.ssh/config`.
  final String destination;

  /// The host as `known_hosts` names it: `host`, or `[host]:port` off port 22.
  final String host;

  /// Whether `known_hosts` already holds a key for it.
  final bool known;

  /// The keys the host offered, as `ssh-keyscan` printed them, ready to append.
  final List<String> scanned;

  /// What the person compares: one line per key, with its type and SHA256 fingerprint.
  final List<String> fingerprints;

  /// Why nothing could be found, in words, or null.
  final String? problem;

  /// Whether a key *is* known for this host, and it is not one the host now shows: a rented
  /// server's address given to a new machine, or somebody in the middle. Never decided here.
  final bool changed;

  /// The `known_hosts` files that hold the old key, to take it out of when a person replaces it.
  final List<String> knownIn;

  /// The first file ssh reads for this host, where a trusted key is written; empty for the default.
  final String writeTo;

  /// Only host setup can pin the key for this destination.
  final bool pinnedByHost;
}

/// Confirming a machine's host key before the first login, **never silently**.
///
/// Every connection here runs with `BatchMode=yes`, so an unknown host key is a failure rather than
/// a prompt — and accepting it blind would be the one step a man in the middle needs. So the key
/// is fetched, its fingerprints are shown, and only a person's yes writes it to `known_hosts`.
abstract interface class HostKeys {
  /// What is known about [destination]'s host key, fetching the keys it offers when none is known.
  Future<HostKeyCheck> check(String destination);

  /// Writes the keys a person accepted to `known_hosts`.
  Future<void> accept(HostKeyCheck check);
}

/// Why the interface cannot accept another key for a managed host.
const String hostKeyPinRefusal = 'Only porelo-host can pin this server key. Run porelo-host up again.';

/// Checks a fleet destination without offering another trust policy for managed hosts.
extension MachineHostKeys on HostKeys {
  /// A host key is pinned by `porelo-host`, never by the interface.
  Future<HostKeyCheck> checkMachine(Machine machine) async {
    if (machine.kind == 'host') {
      return HostKeyCheck(
        destination: machine.host,
        host: machine.host,
        known: false,
        pinnedByHost: true,
        problem: hostKeyPinRefusal,
      );
    }
    return check(machine.host);
  }
}

/// Host keys through OpenSSH's own tools, so an alias, a port or a `known_hosts` elsewhere in the
/// person's ssh config is honored exactly as `ssh` itself will honor it.
class SshHostKeys implements HostKeys {
  /// Constructor, optionally with what runs a program, whose home `~/.ssh` is in, and the desk.
  SshHostKeys({RunWith? run, String? home, Desk? on})
    : _execute = run ?? _runForReal,
      _desk = on ?? desk,
      _paths = home == null
          ? on ?? desk
          : Desk.of((on ?? desk).isWindows ? 'windows' : 'linux', {
              ...(on ?? desk).environment,
              (on ?? desk).isWindows ? 'USERPROFILE' : 'HOME': home,
            });

  final RunWith _execute;
  final Desk _desk;
  final Desk _paths;

  String get _home => _paths.home;

  Future<ProcessResult> _run(List<String> command, {String? input}) => _execute(<String>[
    const <String>{'ssh', 'ssh-keygen', 'ssh-keyscan'}.contains(command.first)
        ? openSsh(command.first, on: _desk)
        : command.first,
    ...command.skip(1),
  ], input: input);

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
    final out = await process.stdout.transform(const SystemEncoding().decoder).join();
    final err = await process.stderr.transform(const SystemEncoding().decoder).join();
    return ProcessResult(process.pid, await process.exitCode, out, err);
  }

  @override
  Future<HostKeyCheck> check(String destination) async {
    // What ssh will actually connect to: the alias resolved, the port, and where it looks.
    final config = await _run(<String>['ssh', '-G', '--', destination]);
    if (config.exitCode != 0) {
      return HostKeyCheck(
        destination: destination,
        host: destination,
        known: false,
        problem:
            'ssh could not read its configuration for $destination: '
            '${'${config.stderr}'.trim()}',
      );
    }
    final settings = <String, String>{};
    for (final line in '${config.stdout}'.split('\n')) {
      final space = line.indexOf(' ');
      if (space > 0) settings.putIfAbsent(line.substring(0, space), () => line.substring(space + 1));
    }
    final hostname = settings['hostname'] ?? destination;
    final port = settings['port'] ?? '22';
    final host = port == '22' ? hostname : '[$hostname]:$port';
    final files = <String>[
      // `ssh -G` expands a home it knows, but nothing here runs a shell to expand one it left.
      for (final named in (settings['userknownhostsfile'] ?? '~/.ssh/known_hosts').split(' ')) _paths.expandHome(named),
    ];
    // What is known for it, as (type, key) pairs, and where.
    final known = <String>{};
    final knownIn = <String>[];
    for (final file in files) {
      final found = await _run(<String>['ssh-keygen', '-F', host, '-f', file]);
      if (found.exitCode != 0) continue;
      knownIn.add(file);
      for (final line in '${found.stdout}'.split('\n')) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        known.add(_keyOf(line));
      }
    }
    final scan = await _run(<String>['ssh-keyscan', '-T', '10', '-H', '-p', port, '--', hostname]);
    final scanned = <String>[
      for (final line in '${scan.stdout}'.split('\n'))
        if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
    ];
    if (knownIn.isNotEmpty && scanned.any((line) => known.contains(_keyOf(line)))) {
      return HostKeyCheck(destination: destination, host: host, known: true);
    }
    if (scanned.isEmpty) {
      return HostKeyCheck(
        destination: destination,
        host: host,
        known: false,
        problem: 'No host key came back from $host. Is it reachable, and is ssh running there?',
      );
    }
    final printed = await _run(<String>['ssh-keygen', '-l', '-f', '-'], input: '${scanned.join('\n')}\n');
    return HostKeyCheck(
      destination: destination,
      host: host,
      known: false,
      changed: knownIn.isNotEmpty,
      knownIn: knownIn,
      writeTo: files.first,
      scanned: scanned,
      fingerprints: <String>[
        for (final line in '${printed.stdout}'.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ],
    );
  }

  /// The type and the key of a `known_hosts` or `ssh-keyscan` line, whatever names the host.
  static String _keyOf(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    final start = fields.first.startsWith('@') ? 2 : 1;
    return fields.length > start + 1 ? '${fields[start]} ${fields[start + 1]}' : line.trim();
  }

  @override
  Future<void> accept(HostKeyCheck check) async {
    if (check.pinnedByHost) throw StateError(check.problem!);
    // A replaced key goes, in every file that held it, before the one the person trusted is added:
    // ssh reads the first match, and an old line left in place would go on refusing.
    for (final file in check.knownIn) {
      await _run(<String>['ssh-keygen', '-R', check.host, '-f', file]);
    }
    // Where ssh will look first, which is ~/.ssh/known_hosts unless its configuration says otherwise.
    final file = File(check.writeTo.isEmpty ? '$_home/.ssh/known_hosts' : check.writeTo);
    final directory = file.parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      await _keepPrivate(directory.path, directory: true);
    }
    final existed = file.existsSync();
    file.writeAsStringSync('${check.scanned.join('\n')}\n', mode: FileMode.append, flush: true);
    if (!existed) await _keepPrivate(file.path);
  }
}
