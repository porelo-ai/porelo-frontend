import 'package:flutter/material.dart';

import '../app/fleet_model.dart';
import 'tokens.dart';

/// What `Remove` refused to do, and the choice about it.
///
/// A pane rather than a toast or a dialog, and it takes the place of whatever was open: the
/// refusal *is* the product working, and it is the most important thing on the screen until
/// somebody has decided about it.
///
/// **Nothing here is a "force" button that quietly discards work.** Each way out says what it
/// does to what is held, and leaving it alone is one of them.
class RefusalView extends StatelessWidget {
  /// Constructor taking the refusal and the ways out of it.
  const RefusalView({required this.refusal, required this.fleet, super.key});

  /// What was refused, and what it said.
  final Refusal refusal;

  /// What the choice acts on.
  final FleetModel fleet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final task = refusal.task;

    return Container(
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(Space.wide),
      // What is held has no length limit, and the choice comes after it.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.pan_tool_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: Space.small),
                Expanded(child: Text('$task was not removed', style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: Space.normal),
            Text(
              refusal.holdsWork
                  ? 'It holds work that never reached the gate. It has been left exactly as it '
                        'was, and nothing has been discarded.'
                  : refusal.stillRunning
                  ? 'It is still running, and a running task is not removed.'
                  : 'Nothing could say whether it holds any work, so it has been left exactly '
                        'as it was.',
            ),
            if (refusal.result.work.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.normal),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.normal),
                decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(Radii.small)),
                child: SelectableText(
                  refusal.result.work,
                  key: const Key('what-is-held'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: Space.loose),
            Wrap(
              spacing: Space.small,
              runSpacing: Space.small,
              children: <Widget>[
                // Leaving it alone is first and is the plain button: it is the answer that destroys
                // nothing, and it should be the easiest one to give.
                FilledButton(onPressed: fleet.letItBe, child: const Text('Leave it alone')),
                if (refusal.holdsWork)
                  OutlinedButton(
                    onPressed: () => fleet.removeWork(task, rescue: true),
                    child: const Text('Push what it holds to the mirror, then remove it'),
                  ),
                if (refusal.holdsWork)
                  OutlinedButton(
                    onPressed: () => fleet.removeWork(task, force: true),
                    child: const Text('Discard what it holds and remove it'),
                  ),
                if (refusal.nothingKnows)
                  OutlinedButton(
                    onPressed: () => fleet.removeWork(task, force: true),
                    child: const Text('Remove it anyway, without knowing'),
                  ),
                if (refusal.stillRunning)
                  OutlinedButton(
                    onPressed: () => fleet.stopAndRemove(task),
                    child: const Text('Stop it, then remove it'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before removing, naming what goes with it.
///
/// What is named here is only what this side knows. What the task *holds* is the daemon's answer,
/// and it arrives as a refusal rather than as a guess made in a dialog.
Future<bool> confirmRemove(BuildContext context, {required String task, required bool running}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $task?'),
        content: Text(
          '${running ? 'It is running: if it holds nothing, it is stopped first. ' : ''}'
          'Its container is its workspace, so it goes, and whatever the agent installed inside '
          'it — packages, caches, anything it built — goes with it and exists nowhere else.\n\n'
          'Work it holds that never reached the gate will stop this, and say so, rather than '
          'being destroyed. To keep it and start it again later, stop it instead.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove it')),
        ],
      ),
    ) ??
    false;

/// Asks before recreating a piece of work.
///
/// **Recreating exists for one reason and the dialog says it**: a task keeps the image it started
/// with, so work that should pick up a newly built environment has to be created again rather than
/// started again. Somebody reaching for this has usually just rebuilt something.
///
/// It is the same destruction a removal is, and the same refusal protects it — work that never
/// reached the gate stops this and says so.
Future<bool> confirmRecreate(BuildContext context, {required String task, required int helpers}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recreate $task from scratch?'),
        content: Text(
          'A task keeps the image it started with, so this is how it picks up a newly built '
          'environment: it is removed and created again rather than started again.\n\n'
          'The container goes and so ${helpers == 1 ? 'does the helper' : 'do the $helpers '
                    'helpers'} beside it. Whatever the agent installed inside — packages, caches, '
          'anything it built — goes with it and exists nowhere else.\n\n'
          'Work it holds that never reached the gate will stop this, and say so, rather than '
          'being destroyed. Nothing is started again until the removal has gone through.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('recreate-it'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove it and build it again'),
          ),
        ],
      ),
    ) ??
    false;
