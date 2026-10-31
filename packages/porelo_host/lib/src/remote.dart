import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ssh.dart';
import 'host_card_ssh.dart';

/// What a command on the host ended with.
class RemoteResult {
  /// Constructor taking the exit code and what was said on standard error.
  const RemoteResult(this.exitCode, this.stderr);

  /// The command's exit code; 255 is ssh's own failure.
  final int exitCode;

  /// What it said on standard error, as it came.
  final String stderr;
}

/// A local refusal before an SSH process exists, safe to retry.
class RemoteNotStarted implements Exception {
  /// Omits launch diagnostics, which can contain private input.
  const RemoteNotStarted();
}

/// Commands run on a host, and files copied to it.
///
/// **A seam**, so the order of `up` is proven without a machine.
abstract interface class Remote {
  /// Runs [command] on [host] as [user] by its shell. [input], when given, is written to its
  /// standard input and nowhere else; each line of its standard output goes to [onLine].
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  });

  /// Copies the local file [from] to [to] on [host].
  Future<RemoteResult> copy(String host, String user, String from, String to);
}

/// The system's own `ssh` and `scp`, against a `known_hosts` of this package's own.
///
/// **`BatchMode=yes` and `StrictHostKeyChecking=yes`**, so nothing prompts and an unknown or
/// changed host key is a refusal. The one key accepted is the provider's, written by [trust].
/// The person's own `known_hosts` is never read or written.
class OpenSsh implements Remote {
  /// Constructor taking the `known_hosts` file this package keeps and the private key to log in with.
  OpenSsh({
    required this.knownHosts,
    required this.identity,
    this.agentOnly = false,
    this.config,
    this.configHost,
    Future<Process> Function(String, List<String>)? start,
    Future<ProcessResult> Function(String, List<String>)? run,
    this.deadline,
  }) : _card = null,
       _start = start ?? ((executable, arguments) => Process.start(executable, arguments)),
       _runProcess = run ?? ((executable, arguments) => Process.run(executable, arguments));

  /// Uses the public config of an already owned host-card connection.
  OpenSsh.sharedHost({
    required HostCardSsh card,
    required String this.config,
    Map<String, String>? environment,
    Future<Process> Function(String, List<String>)? start,
    this.deadline = const Duration(minutes: 5),
  }) : knownHosts = File('$config.known_hosts'),
       identity = '$config.pub',
       agentOnly = false,
       configHost = null,
       _card = card,
       _start = start ?? ((executable, arguments) => Process.start(executable, arguments)),
       _runProcess = ((executable, arguments) => Process.run(executable, arguments)) {
    HostCardSsh.checkConfigPath(card.name, config!, environment: environment, windows: Platform.isWindows);
  }

  /// The completion bound for a submitted host command.
  final Duration? deadline;
  final HostCardSsh? _card;
  final Future<Process> Function(String, List<String>) _start;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  /// The `known_hosts` this package writes the provider's key into.
  final File knownHosts;

  /// Whether only keys served by the local agent may authenticate the host command.
  final bool agentOnly;

  /// The verified host-card configuration, when supplied.
  final String? config;

  /// The verified alias selecting public identity settings, never the destination or account.
  final String? configHost;

  /// The private key that logs in.
  final String identity;

  /// Makes [hostKey] the one key [host] is trusted by.
  Future<void> trust(String host, String hostKey) async {
    await knownHosts.parent.create(recursive: true);
    await knownHosts.writeAsString('$host $hostKey\n');
  }

  List<String> _options(String host, String user) => <String>[
    // A shared host-card connection names its host, account and pin in its own public config alone.
    if (_card != null) ...[
      '-F',
      config!,
      '-o',
      'ControlMaster=no',
      '-o',
      'ProxyCommand=false',
    ] else ...[
      ...pinnedHostSshOptions(knownHosts.path, identity),
      if (agentOnly) ...[
        '-F',
        '/dev/null',
        '-o',
        'IdentityFile=none',
        '-o',
        'PreferredAuthentications=publickey',
      ] else if (config case final file?) ...[
        '-F',
        file,
      ],
      '-o',
      'HostName=$host',
      '-o',
      'User=$user',
      '-o',
      'Port=22',
    ],
    '-o',
    'ConnectTimeout=10',
  ];

  List<String> _destination(String host, String user) =>
      _card != null ? <String>['-T', '--', host] : <String>[configHost ?? '$user@$host'];

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    if (_card case final card?) {
      if (host != card.name || user.isNotEmpty) {
        throw const FormatException('The shared host command must use its admitted account and host alias.');
      }
    }
    Process? process;
    String public(String text) {
      for (final value in const LineSplitter().convert(input ?? '').where((value) => value.isNotEmpty)) {
        text = text.replaceAll(value, '[redacted]');
      }
      return text;
    }

    try {
      process = await _start('ssh', <String>[..._options(host, user), ..._destination(host, user), command]);
      final child = process;
      final out = child.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) => onLine?.call(public(line)));
      final err = child.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
      final work = (() async {
        final writing = (() async {
          try {
            if (input != null) child.stdin.write(input);
            await child.stdin.close();
          } on SocketException {
            // An early host refusal may close its input without draining it.
          }
        })();
        final results = await Future.wait<Object?>([out, err, child.exitCode, writing], eagerError: true);
        return RemoteResult(results[2]! as int, public(results[1]! as String));
      })();
      return await (deadline == null ? work : work.timeout(deadline!));
    } on TimeoutException {
      if (process == null) throw const RemoteNotStarted();
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      return const RemoteResult(255, 'The host command timed out; its result is unconfirmed.');
    } catch (_) {
      if (process == null) throw const RemoteNotStarted();
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      // A process exception can include remote output or input; never publish it with a credential.
      if (input == null) rethrow;
      return const RemoteResult(255, 'The host connection was lost; its result is unconfirmed.');
    }
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    if (agentOnly) {
      final process = await _start('ssh', [..._options(host, user), '$user@$host', 'cat > ${quoteForAShell(to)}']);
      final out = process.stdout.drain<void>();
      final err = process.stderr.transform(utf8.decoder).join();
      SocketException? inputFailure;
      try {
        await process.stdin.addStream(File(from).openRead());
      } on SocketException catch (error) {
        inputFailure = error;
      }
      try {
        await process.stdin.close();
      } on SocketException catch (error) {
        inputFailure ??= error;
      }
      final code = await process.exitCode;
      await out;
      final words = await err;
      if (code == 0 && inputFailure != null) throw inputFailure;
      return RemoteResult(code, words);
    }
    final done = await _runProcess('scp', <String>[
      ..._options(host, user),
      '-q',
      from,
      '${configHost ?? '$user@$host'}:$to',
    ]);
    return RemoteResult(done.exitCode, '${done.stderr}'.trim());
  }
}
