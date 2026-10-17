import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import 'tokens.dart';
import 'dialog_scroll.dart';

/// What a task does with a blocked connection.
///
/// Named by what each permits rather than by the value the contract carries — `prompt` and `deny`
/// are the daemon's words, and *"asks first"* is the person's.
enum Enforcement {
  /// Asks, and the work waits for the answer.
  prompt(
    'prompt',
    'Ask me',
    'The work waits while a question is on screen. Nothing new is '
        'reached until somebody answers.',
  ),

  /// Lets anything new through without asking.
  allow(
    'allow',
    'Let it through',
    'Anything new is reached without asking. Nothing is refused '
        'and nothing is put to anybody.',
  ),

  /// Refuses anything new without asking.
  deny(
    'deny',
    'Refuse it',
    'Anything new is refused without asking. The work never waits, and '
        'never reaches something it was not already allowed.',
  ),

  /// Nothing asks and nothing is refused.
  off(
    'off',
    'Stop asking entirely',
    'Nothing is refused and nothing is asked. The ruleset is '
        'still loaded — this changes whether a blocked connection produces a question, not what '
        'the container can reach.',
  );

  const Enforcement(this.name, this.label, this.what);

  /// As the contract spells it.
  final String name;

  /// What the choice is called.
  final String label;

  /// What it permits, in a sentence.
  final String what;
}

/// Asks how a running task should treat a blocked connection.
///
/// **Two things this screen has to say and nothing else does.** Turning enforcement off does not
/// recall a connection that was already refused — the packet was dropped and nothing retries it —
/// and turning it back on does not recall anything waved through while it was off. **The ruleset
/// is loaded throughout**, so none of this opens a destination by itself.
Future<Enforcement?> askHowToEnforce(BuildContext context, {required String task, required String now}) =>
    showDialog<Enforcement>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('What $task does with a blocked connection'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  now.isEmpty
                      // Every task started before the field existed. An absence to render, not a
                      // fourth mode to invent.
                      ? 'It is running, and stays running. Nothing recorded what it does today.'
                      : 'It is running, and stays running. Today it is “$now”.',
                  key: const Key('what-it-does-now'),
                ),
                const SizedBox(height: Space.normal),
                const Text(
                  'This changes nothing that already happened: a connection that was refused '
                  'stays refused, and anything let through while it was off stays through. The '
                  'ruleset is loaded either way — what changes is whether a blocked connection '
                  'produces a question.',
                  key: Key('changes-nothing-past'),
                ),
                const SizedBox(height: Space.normal),
                for (final mode in Enforcement.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.small),
                    child: OutlinedButton(
                      key: Key('enforce-${mode.name}'),
                      onPressed: () => Navigator.of(context).pop(mode),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: Space.small),
                            Row(
                              children: <Widget>[
                                Text(mode.label, style: Theme.of(context).textTheme.titleSmall),
                                if (mode.name == now) ...<Widget>[
                                  const SizedBox(width: Space.small),
                                  Text(
                                    '— what it does now',
                                    key: const Key('is-what-it-does-now'),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: Space.tight),
                            Text(mode.what, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: Space.small),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('leave-enforcement'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Leave it as it is'),
          ),
        ],
      ),
    );

/// What a change to enforcement did, in one line.
///
/// **`UNCHANGED` is not a failure** — it was already in that mode and nothing was restarted, which
/// is a different sentence from a change that happened.
String whatEnforcementDid(ClearanceSet said, String task) => switch (said.outcome) {
  'CHANGED' =>
    said.was.isEmpty
        ? '$task now does “${said.now}” with a blocked connection.'
        : '$task went from “${said.was}” to “${said.now}”.',
  'UNCHANGED' => '$task was already doing that. Nothing was changed and nothing restarted.',
  'NOT_RUNNING' => '$task is not running, so there is nothing to change.',
  'NO_SUCH_TASK' => 'Nothing on this machine knows $task any more.',
  'UNKNOWN_MODE' => 'That is not a mode this machine knows. ${said.detail}'.trim(),
  'NOT_RECORDED' =>
    'It was changed, and nothing recorded it — so the work list will go on showing what it '
        'showed before.',
  'FAILED' => 'It could not be changed. ${said.detail}'.trim(),
  _ => '${said.outcome}. ${said.detail}'.trim(),
};
