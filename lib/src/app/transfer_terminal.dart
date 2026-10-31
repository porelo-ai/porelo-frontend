import 'dart:async';
import 'dart:convert';

import 'pty.dart';

import 'package:porelo_host/porelo_host.dart';

import 'project_transfers.dart';

/// Opens a transfer terminal with its input echo policy applied before spawning.
///
/// The visible terminal cancels through [DrainingSessionChannel.terminate].
typedef OpenTransferTerminal = DrainingSessionChannel Function(
  String executable,
  List<String> arguments, {
  int columns,
  int rows,
  bool echo,
});

/// Runs a transfer in the visible terminal using this instance's local secrets file.
class TransferTerminal implements CentralTransferSource {
  /// Captures Settings.secretsFile and the opener that presents the terminal.
  TransferTerminal({
    required this.secretsFile,
    required this.openTerminal,
    this.environment,
    this.cli = SecretsFile.keepassxcCli,
    this.deadline = const Duration(minutes: 5),
    this.drainWithin = const Duration(seconds: 5),
  });

  /// The selected local encrypted file, absent until one is chosen.
  final String? secretsFile;

  /// The owner-provided opener, which also presents the terminal for hidden input.
  final OpenTransferTerminal openTerminal;

  /// The platform config location, injectable without reading a machine's setup.
  final Map<String, String>? environment;

  /// The absolute path to the terminal's KeePassXC command.
  final String cli;

  /// The time allowed before terminating the child and draining its output.
  final Duration deadline;

  /// The shutdown bound, whose expiry always leaves the transfer unconfirmed.
  final Duration drainWithin;

  @override
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String line)? onLine,
  }) async {
    final file = secretsFile;
    final card = selection.machine.hostCard;
    if (file == null || card == null) throw const RemoteNotStarted();
    final command = projectTransferFeedCommand(
      direction: direction,
      project: selection.project,
      repositories: selection.repositories,
      card: card,
      config: selection.machine.sshConfig,
      secretsFile: SecretsFile(file, cli: cli),
      environment: environment,
    );
    final channel = openTerminal(command.first, command.skip(1).toList(), echo: false);
    var submitted = false;
    var callbackFailed = false;
    var outputFailed = false;
    var uncertain = false;
    Object? failure;
    StackTrace? failureStack;
    var exitCode = -1;
    final drained = Completer<void>();
    StreamSubscription<String>? subscription;
    try {
      final output = Completer<void>();
      subscription = channel.output
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (line) {
              try {
                if (!submitted && line == projectTransferSubmitted) {
                  submitted = true;
                  onSubmitted();
                } else if (!callbackFailed && line.startsWith(projectTransferOutput)) {
                  onLine?.call(line.substring(projectTransferOutput.length));
                }
              } catch (error, stack) {
                callbackFailed = true;
                if (!output.isCompleted) output.completeError(error, stack);
              }
            },
            onError: (Object error, StackTrace stack) {
              outputFailed = true;
              if (!output.isCompleted) output.completeError(error, stack);
            },
            onDone: () {
              drained.complete();
              if (!output.isCompleted) output.complete();
            },
          );
      try {
        await Future.wait<Object?>([output.future, channel.ended], eagerError: true).timeout(deadline);
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
    } finally {
      try {
        await channel.terminate().timeout(drainWithin);
        // Reaping alone does not deliver the last buffered submission marker.
        final result = await Future.wait<Object?>([drained.future, channel.ended]).timeout(drainWithin);
        exitCode = result[1]! as int;
      } catch (_) {
        uncertain = true;
      } finally {
        await subscription?.cancel();
      }
    }
    final childEnded = uncertain || exitCode < 0 ? channel.ended : null;
    if (callbackFailed && !uncertain && !outputFailed && exitCode >= 0) {
      Error.throwWithStackTrace(failure!, failureStack!);
    }
    uncertain = uncertain || outputFailed || exitCode < 0 || (submitted && failure != null);
    return TransferResult(
      exitCode,
      submitted || uncertain ? '' : 'The local transfer did not start; nothing was sent.',
      notSubmitted: !submitted && !uncertain,
      uncertain: uncertain,
      childEnded: childEnded,
    );
  }
}
