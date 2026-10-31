import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/key_recovery.dart';
import '../app/machines.dart';
import '../app/registry.dart' show RegistryRefusal;
import '../app/run_here.dart' show WorkspaceRefused;
import '../app/session.dart';
import 'dialog_scroll.dart';
import 'pick_a_file.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Asks the desktop where a new file goes; null when the person put the dialog away. A path, never content.
typedef ChooseNewFile = Future<String?> Function({String? title});

/// The desktop's own save dialog.
Future<String?> chooseWithTheDesktop({String? title}) async => (await getSaveLocation(confirmButtonText: title))?.path;

/// Why no key can be replaced from here, while Core's replacement verbs are not connected.
const keyRecoveryNotConnected = 'Replacing a lost or stolen key is not connected to Core on this computer yet.';

/// Reads [scope]'s list and opens its replacement dialog, for [login] when one is chosen.
Future<void> showKeyRecovery(
  BuildContext context, {
  required KeyRecoveryEntry entry,
  required RecoveryScope scope,
  String? login,
  OpenTerminal? open,
  PickAFile pickAFile = pickWithTheDesktop,
  ChooseNewFile chooseNewFile = chooseWithTheDesktop,
}) async {
  final RecoverySituation situation;
  try {
    situation = await entry.situation(scope);
  } on RegistryRefusal catch (refused) {
    if (context.mounted) await _say(context, 'Replace a lost or stolen key', refused.toString());
    return;
  }
  if (!context.mounted) return;
  final recovery = KeyRecovery(situation: situation, core: entry.core, hosts: entry.hosts, receipts: entry.receipts);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => KeyRecoveryDialog(
      recovery: recovery,
      entry: entry,
      login: login,
      open: open,
      pickAFile: pickAFile,
      chooseNewFile: chooseNewFile,
    ),
  );
  recovery.dispose();
}

/// Lets a registry owner choose owners.yml's owners or one host's admins, then opens that list's replacement.
Future<void> showRegistryKeyRecovery(
  BuildContext context, {
  required KeyRecoveryEntry entry,
  OpenTerminal? open,
}) async {
  final scopes = entry.registryScopes;
  if (scopes.isEmpty) {
    await _say(context, 'Replace a lost or stolen key', 'Refresh the registry before replacing a key.');
    return;
  }
  final scope = await showDialog<RecoveryScope>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Which list in owners.yml?'),
      children: [
        for (final scope in scopes)
          SimpleDialogOption(
            key: ValueKey('recovery-scope ${scope.kind.name} ${scope.name}'),
            onPressed: () => Navigator.pop(context, scope),
            child: Text(scope.words),
          ),
      ],
    ),
  );
  if (scope == null || !context.mounted) return;
  await showKeyRecovery(context, entry: entry, scope: scope, open: open);
}

/// Makes a backup key for [scope] in a terminal the person types its passphrase into; answers what Core made.
///
/// The request is kept until its commit is pushed: a terminal that ended without a readable answer is made again under
/// the same ID and base, and a registry commit is pushed from the app's checkout. Only the new file's path reaches Core,
/// and it is never kept; the key and its passphrase never pass through this program.
Future<BackupKeyMade?> makeBackupKey(
  BuildContext context, {
  required KeyRecoveryEntry entry,
  required RecoveryScope scope,
  OpenTerminal? open,
  ChooseNewFile chooseNewFile = chooseWithTheDesktop,
}) async {
  final String? base;
  try {
    base = (await entry.situation(scope)).base;
  } on RegistryRefusal catch (refused) {
    if (context.mounted) await _say(context, 'Make a backup key', refused.toString());
    return null;
  }
  if (base == null) {
    if (context.mounted) await _say(context, 'Make a backup key', 'The commit in force is not read. Read it again.');
    return null;
  }
  final making = BackupKeyMaking(scope: scope, base: base, core: entry.core, receipts: entry.receipts);
  String words;
  BackupKeyMade? made;
  try {
    if (making.unpublished != null) {
      // Core made it already; only its push is owed.
      await making.publish();
      words = 'The backup key’s commit is pushed now.';
    } else {
      final out = await chooseNewFile(
        title: making.pending ? 'Choose the same file again' : 'Make the backup key here',
      );
      if (out == null || !context.mounted) return null;
      final command = await making.start(out);
      if (!context.mounted) return null;
      var code = -1;
      var last = '';
      await runInATerminal(
        context,
        title: 'Make a backup key',
        explanation:
            'Porelo asks for the backup key’s passphrase twice in this terminal. It never passes through this program. '
            'Keep the file offline, on a stick in a drawer, not on this computer.',
        machine: Machine.local(),
        command: command,
        open: open,
        onExit: (exit) => code = exit,
        lastLine: (line) => last = line,
      );
      made = await making.ended(code: code, lastLine: last, out: out);
      words = 'The backup key ${made.fingerprint} is filed in commit ${made.revision}, and pushed.';
    }
  } on RegistryRefusal catch (refused) {
    words = refused.toString();
    if (making.unpublished != null) {
      words =
          '$words The commit is made in the registry checkout and not pushed: make a backup key again to push '
          'it. Nothing else is filed into the registry until then.';
    }
  } on WorkspaceRefused catch (refused) {
    words = '${refused.words} Make a backup key again to push it; nothing else is filed into the registry until then.';
  } on FormatException catch (error) {
    words = error.message;
  }
  if (context.mounted) await _say(context, made == null ? 'Make a backup key' : 'Backup key made', words);
  return made;
}

Future<void> _say(BuildContext context, String title, String words) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(words),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ),
);

/// One key replacement: the person, the old and new key, who confirms it, and every host's lock.
class KeyRecoveryDialog extends StatefulWidget {
  /// Constructor taking the controller and the stand-ins tests replace.
  const KeyRecoveryDialog({
    required this.recovery,
    required this.entry,
    this.login,
    this.open,
    this.pickAFile = pickWithTheDesktop,
    this.chooseNewFile = chooseWithTheDesktop,
    super.key,
  });

  /// The replacement.
  final KeyRecovery recovery;

  /// Where the backup key is made afterwards.
  final KeyRecoveryEntry entry;

  /// The person chosen in the list it was opened from.
  final String? login;

  /// Opens the terminal the backup key's passphrase is typed into.
  final OpenTerminal? open;

  /// Asks for the backup key's file.
  final PickAFile pickAFile;

  /// Asks where a new backup key's file goes.
  final ChooseNewFile chooseNewFile;

  @override
  State<KeyRecoveryDialog> createState() => _KeyRecoveryDialogState();
}

class _KeyRecoveryDialogState extends State<KeyRecoveryDialog> {
  KeyRecovery get _recovery => widget.recovery;
  String? _login;
  bool _stolen = false;
  bool _toldInPerson = false;

  @override
  void initState() {
    super.initState();
    final login = _recovery.review?.login ?? widget.login;
    _stolen = _recovery.review?.stolen ?? false;
    _login = login != null && _recovery.situation.people.containsKey(login) ? login : null;
  }

  /// Opens the backup key's terminal for the reviewed and confirmed replacement, or for its Retry.
  Future<void> _useBackup() async {
    if (_recovery.whyNotBackup(toldInPerson: _toldInPerson) != null) return;
    final file = await widget.pickAFile(title: 'Use this backup key');
    if (file == null || !mounted) return;
    final command = await _recovery.startBackup(file, toldInPerson: _toldInPerson);
    if (command == null || !mounted) return;
    var code = -1;
    var last = '';
    await runInATerminal(
      context,
      title: 'Use the backup key',
      explanation:
          'Porelo reads the backup file once and asks its passphrase in this terminal. Neither passes through this '
          'program, and nothing here keeps the file’s place.',
      machine: Machine.local(),
      command: command,
      open: widget.open,
      onExit: (exit) => code = exit,
      lastLine: (line) => last = line,
    );
    await _recovery.backupEnded(code: code, lastLine: last);
  }

  Future<void> _makeBackup() => makeBackupKey(
    context,
    entry: widget.entry,
    scope: _recovery.situation.scope,
    open: widget.open,
    chooseNewFile: widget.chooseNewFile,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _recovery,
    builder: (context, _) {
      final situation = _recovery.situation;
      final reviewed = _recovery.review;
      final started = _recovery.started;
      final card = _login == null ? null : situation.newCard(_login!);
      final error = Theme.of(context).colorScheme.error;
      final commands = keyRecoveryCommands(
        recovery: _recovery,
        person: _login,
        stolen: _stolen,
        toldInPerson: _toldInPerson,
        useBackup: () => unawaited(_useBackup()),
        makeBackup: () => unawaited(_makeBackup()),
      );
      return AlertDialog(
        key: const Key('key-recovery-dialog'),
        title: const Text('Replace a lost or stolen key'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.small,
              children: [
                if (_recovery.busy) const LinearProgressIndicator(),
                Text('In ${situation.scope.words}. Only ${situation.scope.whoWords} signs it; the login stays.'),
                DropdownButtonFormField<String>(
                  key: ValueKey('recovery-person $_login'),
                  initialValue: _login,
                  decoration: const InputDecoration(labelText: 'Person whose key is lost or stolen'),
                  items: [
                    for (final login in situation.people.keys) DropdownMenuItem(value: login, child: Text(login)),
                  ],
                  onChanged: started || reviewed != null ? null : (value) => setState(() => _login = value),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Lost')),
                    ButtonSegment(value: true, label: Text('Stolen')),
                  ],
                  selected: {_stolen},
                  onSelectionChanged: reviewed != null ? null : (value) => setState(() => _stolen = value.single),
                ),
                if (_stolen)
                  const Text(
                    'A stolen key is revoked by an admin first: the person alone cannot, as the key may be in '
                    'another’s hands. Replacing it here names the old key revoked in the same signed commit. A new '
                    'card signed by the stolen key is never offered. Where no new key waits yet, lock the person in '
                    'the project or on the server now, and replace the key once their new card arrives.',
                  ),
                if (_login case final login?)
                  Text(
                    card == null
                        ? 'No new key of $login waits in the registry. They make one with “I lost my key” under My '
                              'key and card.'
                        : 'Now ${situation.people[login]} · new ${card.fingerprint} (${card.state})',
                  ),
                if (reviewed != null) ..._review(reviewed),
                if (_recovery.filed case final filed?) ..._results(filed),
                if (_recovery.problem case final problem?) Text(problem, style: TextStyle(color: error)),
                for (final command in commands)
                  if (command.id != 'keyRecovery.makeBackup' || _recovery.replaced) _CommandButton(command),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _recovery.busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    },
  );

  List<Widget> _review(RecoveryReview reviewed) => [
    Text('Review', style: Theme.of(context).textTheme.titleSmall),
    Text('Person: ${reviewed.login} (the login stays)'),
    SelectableText('Old key, revoked: ${reviewed.oldFingerprint}'),
    SelectableText('New key: ${reviewed.newFingerprint}'),
    Text('Where: ${reviewed.scope.words}${reviewed.backup ? ', signed by the backup key' : ''}'),
    Text(
      reviewed.hosts.isEmpty
          ? 'The person has no host account to lock.'
          : 'Locked on: ${reviewed.hosts.join(', ')}, each once it confirms.',
    ),
    if (reviewed.stolen)
      CheckboxListTile(
        key: const Key('recovery-told-in-person'),
        value: _toldInPerson,
        onChanged: _recovery.filed != null ? null : (value) => setState(() => _toldInPerson = value ?? false),
        title: const Text('They told me this new fingerprint themselves, not in a message the old key could send.'),
      ),
  ];

  List<Widget> _results(RecoveryFiled filed) => [
    Text('Signed', style: Theme.of(context).textTheme.titleSmall),
    SelectableText(
      'Commit ${filed.revision}${filed.published ? ', pushed' : ', not pushed yet'}',
      key: const Key('recovery-revision'),
    ),
    for (final host in _recovery.review?.hosts ?? const <String>[])
      Text(switch (_recovery.locks[host]) {
        HostLocked() => '$host: locked',
        HostReplaced() => '$host: replaced on the host',
        HostLockPending(:final why) => '$host: $why',
        HostLockRefused(:final why) => '$host: refused: $why',
        null => '$host: Lock not on the host yet.',
      }, key: ValueKey('recovery-host $host')),
    if (_recovery.replaced)
      const Text(
        'Hand the person on: on their computer, My key and card names the host vaults opened by the old key, which '
        'are made again, and the sign-ins they make again there.',
      ),
  ];
}

class _CommandButton extends StatelessWidget {
  const _CommandButton(this.command);

  final Command command;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: command.unavailable ?? command.label,
    child: TextButton(
      key: Key(command.id),
      onPressed: command.available ? command.run : null,
      child: Text(command.label),
    ),
  );
}
