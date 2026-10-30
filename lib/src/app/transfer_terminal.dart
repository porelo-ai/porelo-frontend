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
  });

  /// The selected local encrypted file, absent until one is chosen.
  final String? secretsFile;

  /// The owner-provided opener, which also presents the terminal for hidden input.
  final OpenTransferTerminal openTerminal;

  /// The platform config location, injectable without reading a machine's setup.
  final Map<String, String>? environment;

  /// The absolute path to the terminal's KeePassXC command.
  final String cli;

  /// The terminal completion bound, shorter than the controller's overall bound.
  final Duration deadline;

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
              if (!output.isCompleted) output.completeError(error, stack);
            },
            onDone: () {
              drained.complete();
              if (!output.isCompleted) output.complete();
            },
          );
      final result = await Future.wait<Object?>([output.future, channel.ended], eagerError: true).timeout(deadline);
      return TransferResult(
        result[1]! as int,
        submitted ? '' : 'The local transfer did not start; nothing was sent.',
        notSubmitted: !submitted,
      );
    } finally {
      try {
        await channel.terminate();
      } finally {
        // An exit code can arrive before the last buffered submission marker.
        await Future.wait<Object?>([drained.future, channel.ended]);
        await subscription?.cancel();
      }
    }
  }
}
