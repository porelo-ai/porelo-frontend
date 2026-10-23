import 'dart:convert';
import 'dart:io';

import 'ssh.dart';

/// What a command on the host ended with.
class RemoteResult {
  /// Constructor taking the exit code and what was said on standard error.
  const RemoteResult(this.exitCode, this.stderr);

  /// The command's exit code; 255 is ssh's own failure.
  final int exitCode;

  /// What it said on standard error, as it came.
  final String stderr;
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
    Future<Process> Function(String, List<String>)? start,
    Future<ProcessResult> Function(String, List<String>)? run,
  }) : _start = start ?? ((executable, arguments) => Process.start(executable, arguments)),
       _runProcess = run ?? ((executable, arguments) => Process.run(executable, arguments));

  final Future<Process> Function(String, List<String>) _start;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  /// The `known_hosts` this package writes the provider's key into.
  final File knownHosts;

  /// The private key that logs in.
  final String identity;

  /// Makes [hostKey] the one key [host] is trusted by.
  Future<void> trust(String host, String hostKey) async {
    await knownHosts.parent.create(recursive: true);
    await knownHosts.writeAsString('$host $hostKey\n');
  }

  List<String> _options() => <String>[...pinnedHostSshOptions(knownHosts.path, identity), '-o', 'ConnectTimeout=10'];

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    final process = await _start('ssh', <String>[..._options(), '$user@$host', command]);
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final out = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onLine?.call(line));
    final err = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    await out;
    return RemoteResult(code, (await err).trim());
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async {
    final done = await _runProcess('scp', <String>[..._options(), '-q', from, '$user@$host:$to']);
    return RemoteResult(done.exitCode, '${done.stderr}'.trim());
  }
}
