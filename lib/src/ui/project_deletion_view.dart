import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/project_deletion.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// Asks before removing what Porelo built for a project, then says what is left.
///
/// Three things it will not do. **It never removes on the first press** — what would go is asked
/// for and shown first. **Leaving is the default**, so a stray Return carries nothing. And **it
/// never says "delete the project"**: the project file is still there afterwards, and somebody who
/// read this as deleting their work would spend an afternoon looking for a directory that never
/// moved.
Future<void> openProjectDeletion(
  BuildContext context, {
  required ProjectDeletion deleting,
  required void Function({required bool force}) onRemove,
}) => showDialog<void>(
  context: context,
  builder: (context) => ProjectDeletionDialog(deleting: deleting, onRemove: onRemove),
);

/// The dialog itself, separated so it can be built directly in a test.
class ProjectDeletionDialog extends StatelessWidget {
  /// Constructor taking the model and what agreeing does.
  const ProjectDeletionDialog({required this.deleting, required this.onRemove, super.key});

  /// What would go, what did, and why it was refused.
  final ProjectDeletion deleting;

  /// Removes it. `force` is a second, separate decision.
  final void Function({required bool force}) onRemove;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: deleting,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final answer = deleting.answer;

      return AlertDialog(
        title: Text(deleting.removed ? 'No longer followed' : 'Stop following ${deleting.project}?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (deleting.problem != null)
                  _Block(
                    color: scheme.surfaceContainerLow,
                    child: Text(deleting.problem!, key: const Key('deletion-problem')),
                  )
                else if (deleting.busy && answer == null)
                  const Text('Asking what it would remove…')
                else if (answer != null) ...<Widget>[
                  Text(deleting.words, key: const Key('deletion-says'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.normal),
                  // Said before the list, because it is the fact that decides whether
                  // somebody dares at all — and the one they would otherwise get wrong.
                  const Text('Following its repository again brings it back.', key: Key('it-can-be-built-again')),
                  if (deleting.refused) ...<Widget>[
                    const SizedBox(height: Space.wide),
                    _Block(
                      color: scheme.errorContainer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            answer.outcome == DeleteOutcome.holdsWork
                                ? 'Commits nobody has reviewed'
                                : 'Work that is still running',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: Space.tight),
                          Text(deleting.whatForcingCosts, key: const Key('what-forcing-costs')),
                          const SizedBox(height: Space.small),
                          for (final each in <String>[...answer.unreviewed, ...answer.running])
                            Padding(
                              padding: const EdgeInsets.only(top: Space.tight),
                              child: Text(
                                each,
                                key: const Key('what-stands-in-the-way'),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (answer.removes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Space.wide),
                    Text(deleting.removed ? 'What went' : 'What goes', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: Space.tight),
                    for (final removal in answer.removes)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.tight),
                        child: Text(
                          '${removal.label}  ·  ${removal.what}',
                          key: const Key('what-goes'),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                  ],
                  if (answer.keeps.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Space.wide),
                    Text('What is not touched', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: Space.tight),
                    // **Named by the contract rather than worked out here.** This end does not
                    // know which things are Porelo's, and a confirmation that guessed would
                    // sooner or later name the operator's own file among the casualties.
                    for (final kept in answer.keeps)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.tight),
                        child: Text(
                          kept,
                          key: const Key('what-is-kept'),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (deleting.removed || deleting.problem != null)
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Right'))
          else ...<Widget>[
            // The default and the primary button: a stray Return leaves rather than removes.
            FilledButton(
              key: const Key('leave-the-project-alone'),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Leave it'),
            ),
            TextButton(
              key: const Key('remove-what-was-built'),
              onPressed: deleting.busy ? null : () => onRemove(force: deleting.refused),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              // The word changes with what it now means. Pressing past a refusal is a second
              // decision about something the machine declined, not a retry of the first.
              child: Text(deleting.refused ? 'Stop following anyway' : 'Stop following'),
            ),
          ],
        ],
      );
    },
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Space.normal),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
      borderRadius: BorderRadius.circular(Radii.small),
    ),
    child: child,
  );
}
