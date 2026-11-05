import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ssh.dart';
import 'host_card_ssh.dart';
import 'host_files.dart';
import 'host_file_writer.dart';

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
    this.agentPublicKey = '',
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
       agentPublicKey = '',
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

  /// The public key selected from the agent; empty only for legacy recovery with no saved key.
  final String agentPublicKey;

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

  List<String> _options(String host, String user, {File? agentIdentity}) => <String>[
    // A shared host-card connection names its host, account and pin in its own public config alone.
    if (_card != null) ...[
      '-F',
      config!,
      '-o',
      'ControlMaster=no',
      '-o',
      'ProxyCommand=false',
    ] else ...[
      // A .pub identity asks the agent for that key without ever writing its private half.
      ...pinnedHostSshOptions(knownHosts.path, agentOnly ? agentIdentity?.path ?? '' : identity),
      if (agentOnly) ...[
        '-F',
        '/dev/null',
        if (agentIdentity == null) ...['-o', 'IdentityFile=none'],
        '-o',
        'PreferredAuthentications=publickey',
      ] else if (config case final file?) ...[
        '-F',
        file,
      ],
      '-o',
      'HostName=$host',
      if (user.isNotEmpty) ...['-o', 'User=$user'],
      '-o',
      'Port=22',
    ],
    '-o',
    'ConnectTimeout=10',
  ];

  List<String> _destination(String host, String user) =>
      _card != null ? <String>['-T', '--', host] : <String>['--', configHost ?? _account(host, user)];

  String _account(String host, String user) => user.isEmpty ? host : '$user@$host';

  void _checkCard(String host, String user) {
    if (_card case final card?) {
      if (host != card.name || user.isNotEmpty) {
        throw const FormatException('The shared host command must use its admitted account and host alias.');
      }
    }
  }

  Future<T> _withAgentIdentity<T>(Future<T> Function(File? identity) action) async {
    if (!agentOnly || agentPublicKey.isEmpty) return action(null);
    HostFiles.signingFingerprint(agentPublicKey);
    final writer = HostFileWriter();
    final directory = await writer.createPrivateTemporary(Directory.systemTemp, prefix: 'porelo-agent-key-');
    try {
      final file = File('${directory.path}${Platform.pathSeparator}identity.pub');
      final publicPart = agentPublicKey.trim().split(RegExp(r'\s+')).take(2).join(' ');
      await writer.write(file, utf8.encode('$publicPart\n'));
      return await action(file);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) => _withAgentIdentity(
    (identity) => _run(host, user, command, input: input, onLine: onLine, agentIdentity: identity),
  );

  /// Runs [command] with the public [script] on its standard input: what it prints comes back whole, where [run] would
  /// take every line of a secret input out of it, and a script's lone `}` out of the JSON it answers.
  Future<RemoteResult> runWithPublicInput(
    String host,
    String user,
    String command, {
    required String script,
    void Function(String line)? onLine,
  }) => _withAgentIdentity(
    (identity) =>
        _run(host, user, command, input: script, inputIsPublic: true, onLine: onLine, agentIdentity: identity),
  );

  Future<RemoteResult> _run(
    String host,
    String user,
    String command, {
    String? input,
    bool inputIsPublic = false,
    void Function(String line)? onLine,
    File? agentIdentity,
  }) async {
    _checkCard(host, user);
    Process? process;
    String public(String text) {
      if (inputIsPublic) return text;
      for (final value in const LineSplitter().convert(input ?? '').where((value) => value.isNotEmpty)) {
        text = text.replaceAll(value, '[redacted]');
      }
      return text;
    }

    try {
      process = await _start('ssh', <String>[
        ..._options(host, user, agentIdentity: agentIdentity),
        ..._destination(host, user),
        command,
      ]);
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
    return _withAgentIdentity((identity) => _copy(host, user, from, to, agentIdentity: identity));
  }

  Future<RemoteResult> _copy(String host, String user, String from, String to, {File? agentIdentity}) async {
    _checkCard(host, user);
    if (agentOnly) {
      final process = await _start('ssh', [
        ..._options(host, user, agentIdentity: agentIdentity),
        '--',
        configHost ?? _account(host, user),
        'cat > ${quoteForAShell(to)}',
      ]);
      final out = process.stdout.drain<void>()..ignore();
      final err = process.stderr.transform(utf8.decoder).join()..ignore();
      try {
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
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        rethrow;
      }
    }
    final arguments = <String>[
      ..._options(host, user),
      '-q',
      '--',
      from,
      '${_card != null ? host : configHost ?? _account(host.contains(':') ? '[$host]' : host, user)}:$to',
    ];
    if (deadline case final limit?) return _copyWithin(limit, arguments);
    final done = await _runProcess('scp', arguments);
    return RemoteResult(done.exitCode, '${done.stderr}'.trim());
  }

  static const _outputGrace = Duration(seconds: 2);

  /// Runs `scp` with [arguments], ended once it outlives [limit]: a stalled copy never holds its caller without end.
  Future<RemoteResult> _copyWithin(Duration limit, List<String> arguments) async {
    final process = await _start('scp', arguments);
    final out = process.stdout.drain<void>()..ignore();
    final err = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join()..ignore();
    await process.stdin.close().catchError((Object _) {});
    // scp's own ssh can hold the output open after scp ended: what came within a short grace is the answer.
    Future<String> said() async {
      await out.timeout(_outputGrace, onTimeout: () {});
      return (await err.timeout(_outputGrace, onTimeout: () => '')).trim();
    }

    try {
      final code = await process.exitCode.timeout(limit);
      return RemoteResult(code, await said());
    } on TimeoutException {
      // Asked first, scp ends the ssh it started; only one that does not end is killed.
      process.kill();
      await process.exitCode.timeout(
        _outputGrace,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return process.exitCode;
        },
      );
      final within = limit.inMinutes >= 1 ? '${limit.inMinutes} minutes' : '${limit.inSeconds} seconds';
      return RemoteResult(
        255,
        'Copying to the host gave no answer within $within and was ended; nothing it copied is confirmed. '
        'Check that this computer reaches the host, then try again.',
      );
    }
  }
}
