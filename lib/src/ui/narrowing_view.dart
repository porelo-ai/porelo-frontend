import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/narrowing.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// Takes a name back from work that is already running.
///
/// **The sentence this screen exists to get right is what it does not do.** Taking a name back
/// stops new connections; the ruleset accepts established traffic without consulting the set
/// again, so a transfer already in flight runs to its end. Drawing this as *"the host is now
/// unreachable"* would be untrue at exactly the moment somebody is relying on it — and the honest
/// next step, when a transfer really has to stop, is stopping the task.
Future<void> openNarrowing(
  BuildContext context, {
  required Narrowing narrowing,
  required VoidCallback onConsider,
  required VoidCallback onApply,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => NarrowingDialog(
        narrowing: narrowing,
        onConsider: onConsider,
        onApply: onApply,
      ),
    );

/// The dialog itself, separated so it can be built directly in a test.
class NarrowingDialog extends StatefulWidget {
  /// Constructor taking the model and what can be done to it.
  const NarrowingDialog({
    required this.narrowing,
    required this.onConsider,
    required this.onApply,
    super.key,
  });

  /// What is being taken back, and what came back.
  final Narrowing narrowing;

  /// Works out what it would take back, taking nothing back.
  final VoidCallback onConsider;

  /// Takes back what was previewed.
  final VoidCallback onApply;

  @override
  State<NarrowingDialog> createState() => _NarrowingDialogState();
}

class _NarrowingDialogState extends State<NarrowingDialog> {
  final _names = TextEditingController();

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.narrowing,
        builder: (context, _) {
          final narrowing = widget.narrowing;
          final task = narrowing.task;
          final result = narrowing.applied;

          return AlertDialog(
            title: Text('Take something back from ${task?.name ?? 'this work'}'),
            content: SizedBox(
              width: Sizes.reachDialog,
              child: DialogScroll(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Said before anything is typed, because it is the thing somebody would
                    // otherwise assume and act on.
                    Text(
                      'It is running, and stays running. This stops new connections — a transfer '
                      'already in flight runs to its end, because the ruleset lets established '
                      'traffic through without asking again. If one has to stop now, stopping the '
                      'task is what does that.',
                      key: const Key('stops-new-connections'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.normal),
                    TextField(
                      key: const Key('narrow-names'),
                      controller: _names,
                      autofocus: true,
                      enabled: result == null,
                      decoration: const InputDecoration(
                        labelText: 'Host names to take back',
                        hintText: 'files.example.test',
                        helperText: 'A name that is not granted to this run is ignored, '
                            'not an error.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: narrowing.ask,
                    ),
                    const SizedBox(height: Space.wide),
                    if (result == null) ...<Widget>[
                      Text('How far it goes',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: Space.tight),
                      // Nothing preselected, for the daemon's own reason: narrowing only the run
                      // when somebody meant the project too leaves the next task starting with
                      // the host still open.
                      _WhichScope(narrowing: narrowing),
                    ],
                    if (narrowing.problem != null) ...<Widget>[
                      const SizedBox(height: Space.normal),
                      _Bad(words: narrowing.problem!, id: 'narrow-problem'),
                    ],
                    if (narrowing.preview != null) ...<Widget>[
                      const SizedBox(height: Space.wide),
                      _WhatItWouldTake(preview: narrowing.preview!),
                    ],
                    if (result != null) ...<Widget>[
                      const SizedBox(height: Space.normal),
                      Text(narrowing.words, key: const Key('narrow-result')),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              if (result != null)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Right'),
                )
              else ...<Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Leave it as it is'),
                ),
                if (narrowing.preview == null)
                  FilledButton(
                    key: const Key('narrow-preview'),
                    onPressed:
                        narrowing.ready && !narrowing.busy ? widget.onConsider : null,
                    child: const Text('Show what this would take back'),
                  )
                else
                  FilledButton(
                    key: const Key('narrow-apply'),
                    onPressed: narrowing.busy ? null : widget.onApply,
                    child: const Text('Take it back'),
                  ),
              ],
            ],
          );
        },
      );
}

/// The scope, with nothing chosen until somebody chooses.
class _WhichScope extends StatelessWidget {
  const _WhichScope({required this.narrowing});

  final Narrowing narrowing;

  @override
  Widget build(BuildContext context) => ChoiceField<Scope>(
        id: 'narrow-scope',
        label: 'Taken back from',
        value: narrowing.scope,
        onChanged: (chosen) => chosen == null ? null : narrowing.choose(chosen),
        choices: const <Choice<Scope>>[
          Choice(Scope.run, 'Just this run', id: 'narrow-scope-run',
              means: 'The project file keeps the name, so the next task here starts with it open '
                  'again.'),
          Choice(Scope.runAndProject, 'This run and the project', id: 'narrow-scope-project',
              means: 'Taken out of the project file too, so no task here starts with it again.'),
        ],
      );
}

/// What a preview says would be taken back.
class _WhatItWouldTake extends StatelessWidget {
  const _WhatItWouldTake({required this.preview});

  final Narrowed preview;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What this would take back',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Space.tight),
          if (preview.closes.isEmpty)
            const Text(
              'None of these is granted to this run, so there is nothing to take back.',
              key: Key('nothing-to-take-back'),
            )
          else ...<Widget>[
            for (final name in preview.closes)
              Text(name,
                  key: const Key('would-close'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: Space.tight),
            Text(
              // Zero is a real state and not a fault: the name was granted and the container
              // never reached it, so nothing was in the set.
              preview.addresses == 0
                  ? 'Nothing is in the firewall for it — it was granted and never reached.'
                  : '${preview.addresses} '
                      '${preview.addresses == 1 ? 'address comes' : 'addresses come'} out of the '
                      'firewall. They are the ones recorded when it was granted, not what the '
                      'name resolves to now.',
              key: const Key('what-comes-out'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );
}

class _Bad extends StatelessWidget {
  const _Bad({required this.words, required this.id});

  final String words;
  final String id;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.normal),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Text(words, key: Key(id)),
      );
}
