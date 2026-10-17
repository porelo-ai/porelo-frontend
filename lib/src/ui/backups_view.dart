import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/backups.dart';
import 'how_long.dart';
import 'panes.dart';
import 'tokens.dart';

/// What has been backed up of a project's mirror.
///
/// **A record is not the bundle**, and the screen keeps them apart: when it was taken and how much
/// it held are what was true then; whether the file is still there and how big it is are read from
/// disk now. A bundle somebody moved is shown as missing rather than dropped — dropping it would
/// say the backup was never taken, which is a different and worse statement.
class BackupsView extends StatelessWidget {
  /// Constructor taking what has been taken and what can be done with it.
  const BackupsView({
    required this.backups,
    required this.onConsider,
    required this.onConsiderRestoring,
    required this.onRestore,
    required this.onRemove,
    required this.onLetItBe,
    required this.onClose,
    super.key,
  });

  /// What the machine said.
  final Backups backups;

  /// Asks what removing one would take, removing nothing.
  final void Function(Backup backup) onConsider;

  /// Asks what restoring from one would take, restoring nothing.
  final void Function(Backup backup) onConsiderRestoring;

  /// Restores from the one being considered. `force` is a second, separate decision.
  final void Function({required bool force}) onRestore;

  /// Removes the one being considered.
  final VoidCallback onRemove;

  /// Puts the confirmation away.
  final VoidCallback onLetItBe;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: backups,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;

      return Column(
        children: <Widget>[
          PaneHeader(
            title: backups.repository == null
                ? 'Backups of ${backups.project}'
                : 'Backups of ${backups.project} · ${backups.repository}',
            trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
          ),
          if (backups.problem != null)
            _Block(
              colour: scheme.errorContainer,
              child: Text(backups.problem!, key: const Key('backups-problem')),
            ),
          if (backups.removed != null)
            _Block(
              colour: scheme.surfaceContainerHighest,
              child: Text(backups.words, key: const Key('backup-says')),
            ),
          if (backups.restoring != null)
            _Block(
              colour: backups.restoring!.done ? scheme.surfaceContainerHighest : scheme.errorContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(backups.restoreWords, key: const Key('restore-says')),
                  if (!backups.restoring!.done) ...<Widget>[
                    const SizedBox(height: Space.small),
                    Row(
                      children: <Widget>[
                        // Leaving is the default, as everywhere else that destroys something
                        // no other copy of exists.
                        FilledButton(
                          key: const Key('leave-the-mirror'),
                          autofocus: true,
                          onPressed: onLetItBe,
                          child: const Text('Leave it'),
                        ),
                        const SizedBox(width: Space.small),
                        TextButton(
                          key: const Key('restore-it'),
                          onPressed: backups.busy
                              ? null
                              // Forcing is a second decision about something the machine
                              // declined, not a retry: the word changes with what it means.
                              : () => onRestore(force: backups.restoring!.holdsWork),
                          style: TextButton.styleFrom(foregroundColor: scheme.error),
                          child: Text(backups.restoring!.holdsWork ? 'Restore it anyway' : 'Restore it'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (backups.considering != null)
            _Block(
              colour: scheme.errorContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Remove this backup? It held ${backups.considering!.refs} '
                    '${backups.considering!.refs == 1 ? 'push' : 'pushes'} nobody had '
                    'reviewed — that is what a restore from it would bring back.',
                    key: const Key('what-removing-costs'),
                  ),
                  const SizedBox(height: Space.small),
                  Row(
                    children: <Widget>[
                      // Leaving is the default, as everywhere else that destroys something.
                      FilledButton(
                        key: const Key('keep-the-backup'),
                        autofocus: true,
                        onPressed: onLetItBe,
                        child: const Text('Keep it'),
                      ),
                      const SizedBox(width: Space.small),
                      TextButton(
                        key: const Key('remove-the-backup'),
                        onPressed: backups.busy ? null : onRemove,
                        style: TextButton.styleFrom(foregroundColor: scheme.error),
                        child: const Text('Remove it'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: Space.small),
              children: <Widget>[
                if (backups.busy && backups.taken.isEmpty)
                  const Padding(padding: EdgeInsets.all(Space.normal), child: Text('Asking the machine…'))
                else if (backups.taken.isEmpty && backups.problem == null)
                  const Padding(
                    padding: EdgeInsets.all(Space.normal),
                    // **Nothing recorded, never nothing exists.** A bundle written by hand, or
                    // before the record existed, is invisible here and always will be.
                    child: Text(
                      'Nothing is recorded for this project. That is not the same as no '
                      'bundle existing: one written by hand, or before Porelo kept a record, '
                      'is not listed here and never will be.',
                      key: Key('nothing-recorded'),
                    ),
                  ),
                for (final backup in backups.taken)
                  _BackupRow(
                    backup: backup,
                    onConsider: () => onConsider(backup),
                    onConsiderRestoring: () => onConsiderRestoring(backup),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// One backup, with what was true then and what is true now.
class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.backup, required this.onConsider, required this.onConsiderRestoring});

  final Backup backup;
  final VoidCallback onConsider;
  final VoidCallback onConsiderRestoring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = backup.takenAt;

    return ListTile(
      dense: true,
      leading: Icon(
        backup.present ? Icons.inventory_2_outlined : Icons.help_outline,
        size: Sizes.mark,
        color: backup.present ? scheme.primary : scheme.error,
      ),
      title: Text(
        when == null ? backup.bundle : '${howLongSince(when) ?? ''} ago · ${backup.bundle}',
        key: const Key('backup'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      subtitle: Text(
        backup.present
            // What was true then, and what is true now, in that order and told apart.
            ? '${backup.refs} ${backup.refs == 1 ? 'push' : 'pushes'} when it was taken · '
                  '${backup.size} now'
            : '${backup.refs} ${backup.refs == 1 ? 'push' : 'pushes'} when it was taken · '
                  'the file is not there any more',
        key: const Key('backup-detail'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: const Key('consider-restoring'),
            icon: const Icon(Icons.restore, size: Sizes.rowIcon),
            tooltip: 'Restore the mirror from this backup',
            // **Only when the file is there.** Restoring from a bundle somebody moved would fail
            // at the machine, and offering it says the record is the thing when it is not.
            onPressed: backup.present ? onConsiderRestoring : null,
          ),
          IconButton(
            key: const Key('consider-removing'),
            icon: const Icon(Icons.delete_outline, size: Sizes.rowIcon),
            tooltip: 'Remove this backup',
            onPressed: onConsider,
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.colour, required this.child});

  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Container(width: double.infinity, padding: const EdgeInsets.all(Space.normal), color: colour, child: child);
}
