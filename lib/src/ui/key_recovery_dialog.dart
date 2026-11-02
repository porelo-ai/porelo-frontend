import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app/identity.dart';
import '../app/key_recovery.dart';
import '../app/machines.dart';
import '../app/pty.dart' show TerminalStillRunning;
import '../app/session.dart';
import 'identity_view.dart';
import 'pick_a_file.dart';
import 'unlock_terminal.dart';

/// What the organization's and a host's pages run for a person's keys: every passphrase stays in a terminal.
class KeyCommands {
  /// Constructor taking where requests are kept and the stand-ins tests replace.
  KeyCommands({
    required this.receipts,
    this.open,
    this.pickAFile = pickWithTheDesktop,
    this.chooseNewFile = chooseWithTheDesktop,
    this.writeCard = writeCardFile,
    this.model,
    Map<String, String>? environment,
  }) : environment = environment ?? Platform.environment;

  /// Where a request is kept for a retry.
  final RecoveryReceipts receipts;

  /// Opens the terminal; a stand-in in tests.
  final OpenTerminal? open;

  /// Asks for a backup key's file.
  final PickAFile pickAFile;

  /// Asks where a new backup key's file, or a lost key's new card, goes.
  final ChooseNewFile chooseNewFile;

  /// Writes a lost key's new card.
  final WriteCard writeCard;

  /// The identity the lost-key dialog runs on, a fake-backed one in tests.
  final IdentityModel? model;

  /// Where `XDG_CONFIG_HOME` and `HOME` are read, for the new card's file.
  final Map<String, String> environment;

  /// Makes a backup key for [scope] against [base], the revision the page read.
  Future<void> makeBackup(BuildContext context, {required BackupScope scope, required String base}) =>
      _asking(context, BackupKeyRequest(scope: scope, use: BackupKeyUse.make, base: base, receipts: receipts));

  /// Puts the new card made here in place of the lost key, signed by the backup key of [scope], against [base].
  Future<void> useBackup(BuildContext context, {required BackupScope scope, required String base}) =>
      _asking(context, BackupKeyRequest(scope: scope, use: BackupKeyUse.replace, base: base, receipts: receipts));

  /// Opens the replacement of the person's own lost key; [places] are the ones they hold, which a backup key may serve,
  /// and [base] is the revision the page read.
  Future<void> replaceLostKey(BuildContext context, {required List<BackupScope> places, required String base}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => ReplaceLostKeyDialog(
          model: model ?? IdentityModel(Identity()),
          open: open,
          places: places,
          chooseNewFile: chooseNewFile,
          writeCard: writeCard,
          useBackup: (scope) => useBackup(dialog, scope: scope, base: base),
        ),
      );

  Future<void> _asking(BuildContext context, BackupKeyRequest request) async {
    final String? words;
    try {
      words = await request.attempt(() => _attempt(context, request));
    } on BackupKeyRefused catch (refused) {
      if (context.mounted) await _say(context, _title(request), refused.words);
      return;
    }
    if (words != null && context.mounted) await _say(context, _title(request), words);
  }

  static String _title(BackupKeyRequest request) =>
      request.use == BackupKeyUse.make ? 'Make a backup key' : 'Use the backup key';

  /// One attempt: the file asked for, the terminal, and the words to say; none when the person put it away.
  Future<String?> _attempt(BuildContext context, BackupKeyRequest request) async {
    final make = request.use == BackupKeyUse.make;
    final file = make
        ? await chooseNewFile(title: request.pending ? 'Choose the same file again' : 'Make the backup key here')
        : await pickAFile(title: 'Use this backup key');
    if (file == null || !context.mounted) return null;
    try {
      final command = await request.start(file, card: Identity.cardFile(environment));
      // From here the request is kept: a terminal that never opened restores it as it was.
      var opened = false;
      TerminalEnd? end;
      try {
        if (!context.mounted) return null;
        var last = '';
        end = await runInATerminal(
          context,
          title: _title(request),
          explanation: make
              ? 'Porelo asks for the backup key’s passphrase twice in this terminal. It never passes through this '
                    'program. Keep the file offline, on a stick in a drawer, not on this computer.'
              : 'Porelo reads the backup file once and asks its passphrase in this terminal. Neither passes through '
                    'this program, and nothing here keeps the file’s place.',
          machine: Machine.local(),
          command: command,
          open: _toldWhenOpened(() => opened = true),
          lastLine: (line) => last = line,
          waitsOnItsProgram: true,
        );
        final done = await request.ended(code: end.code, lastLine: last, file: file, started: end.started);
        return _doneWords(request, done, file);
      } finally {
        if (end == null && !opened) await _neverStarted(request, file);
      }
    } on FormatException catch (error) {
      return error.message;
    } on TerminalStillRunning catch (still) {
      // Core may still write the key: the attempt runs until its program has ended.
      try {
        await still.ended;
      } on Object {
        // Its end could not be read: the request stays kept all the same.
      }
      return 'The terminal was put away while Porelo still ran in it, and its answer was not read. Porelo may have '
          'made it, so its request is kept: ask again, and it answers what it made under that request.';
    }
  }

  static String _doneWords(BackupKeyRequest request, BackupKeyDone done, String file) {
    if (request.use == BackupKeyUse.replace) return 'The backup key put your new card in place of the lost key.';
    final key = done.fingerprint == null ? 'The backup key' : 'The backup key ${done.fingerprint}';
    final kept = done.file != null && done.file != file ? ' Its file is ${done.file}, not $file.' : '';
    return '$key is filed for ${request.scope.words}.$kept';
  }

  OpenTerminal _toldWhenOpened(void Function() opened) => (executable, arguments, {int columns = 80, int rows = 24}) {
    opened();
    return (open ?? openHere)(executable, arguments, columns: columns, rows: rows);
  };

  static Future<void> _neverStarted(BackupKeyRequest request, String file) async {
    try {
      await request.ended(code: null, lastLine: '', file: file, started: false);
    } on BackupKeyRefused {
      // Its words say nothing ran, and nobody waits for them.
    }
  }
}

Future<void> _say(BuildContext context, String title, String words) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('backup-key-said'),
    title: Text(title),
    content: Text(words),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);
