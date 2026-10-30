import 'dart:async';
import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';

import 'project_transfers.dart';
import 'session.dart';

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
  final OpenTerminal openTerminal;

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
    final channel = openTerminal(command.first, command.skip(1).toList());
    var submitted = false;
    var localRefusal = false;
    try {
      // Once the terminal exists, a lost output stream cannot prove SSH never started.
      onSubmitted();
      final output = channel.output
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) {
            if (!submitted && line == projectTransferNotSubmitted) {
              localRefusal = true;
            } else if (!submitted && line == projectTransferSubmitted) {
              submitted = true;
              localRefusal = false;
            } else {
              onLine?.call(line);
            }
          });
      final result = await Future.wait<Object?>([output, channel.ended], eagerError: true).timeout(deadline);
      if (!submitted && !localRefusal) throw StateError('The terminal result is unconfirmed.');
      return TransferResult(result[1]! as int, '', notSubmitted: localRefusal);
    } finally {
      await channel.close();
      await channel.ended;
    }
  }
}
