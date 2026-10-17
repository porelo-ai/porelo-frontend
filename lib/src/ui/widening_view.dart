import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/widening.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// Lets work that is already running reach something it could not reach before.
///
/// A dialog rather than a pane, because it is a decision taken about the task in front of
/// somebody and then finished with — not a place to be.
///
/// Three things it is careful about, all of them easy to get wrong and expensive when wrong:
/// nothing is granted before it has been shown; the scope is never chosen by the screen; and what
/// it says afterwards is that the host is *reachable from the next attempt*, never that the
/// request that failed will now succeed.
Future<void> openWidening(
  BuildContext context, {
  required Widening widening,
  required VoidCallback onConsider,
  required VoidCallback onApply,
}) => showDialog<void>(
  context: context,
  builder: (context) => WideningDialog(widening: widening, onConsider: onConsider, onApply: onApply),
);

/// The dialog itself, separated so it can be built directly in a test.
class WideningDialog extends StatefulWidget {
  /// Constructor taking the model and what can be done to it.
  const WideningDialog({required this.widening, required this.onConsider, required this.onApply, super.key});

  /// What is being asked for, and what came back.
  final Widening widening;

  /// Works out what the change would grant, granting nothing.
  final VoidCallback onConsider;

  /// Grants what was previewed.
  final VoidCallback onApply;

  @override
  State<WideningDialog> createState() => _WideningDialogState();
}

class _WideningDialogState extends State<WideningDialog> {
  final _names = TextEditingController();

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.widening,
    builder: (context, _) {
      final widening = widget.widening;
      final task = widening.task;
      final result = widening.applied;
      final refused = widening.preview?.outcome.failedOutright ?? false;

      return AlertDialog(
        title: Text('Let ${task?.name ?? 'this work'} reach something new'),
        content: SizedBox(
          width: Sizes.reachDialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'It is running, and stays running. A grant takes effect on the next '
                  'connection it attempts.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Space.normal),
                TextField(
                  key: const Key('widen-names'),
                  controller: _names,
                  autofocus: true,
                  enabled: result == null,
                  decoration: const InputDecoration(
                    labelText: 'Host names',
                    hintText: 'files.example.test, docs.example.test',
                    helperText:
                        'A grant covers what is under a name. '
                        'Sets cannot be granted this way.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: widening.ask,
                ),
                const SizedBox(height: Space.wide),
                if (result == null) ...<Widget>[
                  Text('How far it goes', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Space.tight),
                  // Nothing is preselected, deliberately. The daemon refuses a call with no
                  // scope rather than picking one, and the reason is the same here: these are
                  // two different intentions, not a setting with a sensible default.
                  _WhichScope(widening: widening),
                ],
                if (widening.problem != null) ...<Widget>[
                  const SizedBox(height: Space.normal),
                  _Bad(words: widening.problem!, id: 'widen-problem'),
                ],
                // A preview the machine refused is an answer, not a list of what it would grant:
                // drawn as the refusal, with nothing left to grant.
                if (widening.preview != null && refused) ...<Widget>[
                  const SizedBox(height: Space.wide),
                  _WhatItDid(result: widening.preview!, scope: widening.scope),
                ] else if (widening.preview != null) ...<Widget>[
                  const SizedBox(height: Space.wide),
                  _WhatItWouldGrant(preview: widening.preview!, scope: widening.scope),
                ],
                if (result != null) ...<Widget>[
                  const SizedBox(height: Space.normal),
                  _WhatItDid(result: result, scope: widening.scope),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (result != null)
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Right'))
          else ...<Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Leave it as it is')),
            if (refused)
              const SizedBox.shrink()
            else if (widening.preview == null)
              FilledButton(
                key: const Key('widen-preview'),
                onPressed: widening.ready && !widening.busy ? widget.onConsider : null,
                child: const Text('Show what this would grant'),
              )
            else
              FilledButton(
                key: const Key('widen-apply'),
                onPressed: widening.busy ? null : widget.onApply,
                child: const Text('Grant it'),
              ),
          ],
        ],
      );
    },
  );
}

/// The scope, with nothing chosen until somebody chooses.
class _WhichScope extends StatelessWidget {
  const _WhichScope({required this.widening});

  final Widening widening;

  @override
  Widget build(BuildContext context) => ChoiceField<Scope>(
    // Null until somebody chooses — which is the behavior wanted, not a gap to be filled in
    // with a default.
    id: 'widen-scope',
    label: 'Let through for',
    value: widening.scope,
    onChanged: (chosen) => chosen == null ? null : widening.choose(chosen),
    choices: const <Choice<Scope>>[
      Choice(
        Scope.run,
        'Just this run',
        id: 'widen-scope-run',
        means:
            'Gone when the task is resumed: a resumed container rebuilds its rules from '
            'what is on disk, and this is not written to disk.',
      ),
      Choice(
        Scope.runAndProject,
        'This run and the project file',
        id: 'widen-scope-project',
        means: 'Every task started in this project afterwards has it too.',
      ),
    ],
  );
}

/// What a grant would do, before it is made.
class _WhatItWouldGrant extends StatelessWidget {
  const _WhatItWouldGrant({required this.preview, required this.scope});

  final Widened preview;
  final Scope? scope;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'This is what it would grant',
            key: const Key('widen-preview-heading'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Space.tight),
          // The names, not a count of them. Somebody agreeing to this is entitled to see what
          // they are agreeing to, which is the same rule the egress preview follows.
          for (final name in preview.opens)
            Padding(
              padding: const EdgeInsets.only(left: Space.small, top: Space.tight),
              child: Text(
                '+ $name',
                key: const Key('widen-opens'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          if (preview.opens.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: Space.tight),
              child: Text('Nothing. It can reach all of that already.'),
            ),
          if (preview.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.tight),
            Text(preview.detail, key: const Key('widen-detail')),
          ],
          if (scope == Scope.run) ...<Widget>[
            const SizedBox(height: Space.small),
            Text('For this run only. Resuming the task loses it.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// What a grant did.
class _WhatItDid extends StatelessWidget {
  const _WhatItDid({required this.result, required this.scope});

  final Widened result;
  final Scope? scope;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outcome = result.outcome;

    // Three readings, and the middle one is the whole reason this is not a boolean.
    // NO_PROJECT_FILE means the run *was* widened and only the file was not written; showing it
    // as a failure would tell somebody the task still cannot reach the host when it can.
    final bad = outcome.failedOutright;
    final partial = outcome.reached && !result.persisted && scope == Scope.runAndProject;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(
        color: bad
            ? scheme.errorContainer
            : partial
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_heading(outcome), key: const Key('widen-outcome'), style: Theme.of(context).textTheme.titleSmall),
          for (final name in result.opens)
            Padding(
              padding: const EdgeInsets.only(left: Space.small, top: Space.tight),
              child: Text(
                '+ $name',
                key: const Key('widen-opens'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          if (result.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.tight),
            Text(result.detail, key: const Key('widen-detail')),
          ],
          if (outcome.reached) ...<Widget>[
            const SizedBox(height: Space.small),
            // The sentence most likely to be got wrong. A refused connection was dropped at the
            // packet level and is gone; whether the agent tries again is the agent's business.
            Text(
              'Reachable from the next attempt the agent makes. The connection that was '
              'refused is gone, and nothing here retries it.',
              key: const Key('widen-next-attempt'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (outcome.reached && result.persisted) ...<Widget>[
            const SizedBox(height: Space.tight),
            Text(
              'Written to the project file, so the next task starts with it.',
              key: const Key('widen-persisted'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (outcome.reached && !result.persisted && scope == Scope.run) ...<Widget>[
            const SizedBox(height: Space.tight),
            Text('This run only. Resuming the task loses it.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  static String _heading(WidenOutcome outcome) => switch (outcome.name) {
    'WIDENED' => 'Granted',
    // Not "failed". The run was widened; only the file was not written.
    'NO_PROJECT_FILE' => 'Granted for this run, and not written to the project',
    'NO_CHANGE' => 'It could already reach all of that',
    'NOT_RUNNING' => 'There is no running container to widen',
    'REFUSED_BY_CLASS' => 'Refused: this project reaches nothing by design',
    'REFUSED_NAME' => 'Refused: that name is refused on purpose',
    'FAILED' => 'That did not work',
    // A value added after this build shipped. Rendered, never thrown on.
    _ => outcome.label,
  };
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
