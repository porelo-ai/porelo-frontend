import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world.dart';

/// The id of the save the planner holds for a change to [story], named as the planner's target, as the steps name it.
String heldSaveId(String story) => 'held-$story';

/// A save the planner holds for a change to [story], named as the planner's target: one a window made, which the planner resends, or a halted run's,
/// which it only drops. Its one command was refused for an unreachable forge.
Map<String, dynamic> heldSaveOf(String story, {required bool run}) => {
  'id': heldSaveId(story),
  'run': run,
  'earlier': false,
  'resendable': !run,
  'commands': [
    {
      'id': '${heldSaveId(story)}-1',
      'kind': 'SET_FIELDS',
      'target': story,
      'state': 'REFUSED',
      'reason': 'Unreachable',
      'subject': 'the forge did not answer',
    },
  ],
};

/// The held saves of [project] as Needs you shows them, among the rows that need the person.
Finder heldSavesInNeedsYou(String project) =>
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.byKey(Key('held-saves $project')));

/// Presses [action], `resend` or `drop`, on the held save of [story].
Future<void> tapHeldSave(WidgetTester tester, String action, String story) async {
  final button = find.byKey(Key('held-save-$action ${heldSaveId(story)}'));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await World.settle(tester);
}
