import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world.dart';

/// The id of the save the planner holds for a change to [story], named as the planner's target, as the steps name it.
String heldSaveId(String story) => 'held-$story';

/// A save the planner holds for a change to [story], named as the planner's target: one a window made, which the planner resends, or a halted run's,
/// which it only drops. Its one command was refused for an unreachable forge, twice, the forge answering 502.
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
  'reason': 'The forge did not answer the save.',
  'changes': [
    {'target': story, 'field': 'status', 'now': 'Backlog', 'nowAt': '2026-11-26T07:00:00Z', 'saved': 'In analysis'},
  ],
  'tries': [
    for (final at in ['07:01', '07:03'])
      {
        'at': '2026-11-26T$at:00Z',
        'result': 'REFUSED',
        'reason': 'Unreachable',
        'answer': {'status': 502, 'text': 'Bad gateway', 'requestId': heldRequestId},
      },
  ],
  'answer': {'status': 502, 'text': 'Bad gateway', 'requestId': heldRequestId},
  // Three identical saves the planner folded into this one line, the newest last and named by the line's id.
  'saves': ['${heldSaveId(story)}-a', '${heldSaveId(story)}-b', heldSaveId(story)],
};

/// The request id the forge gave its last answer to a held save.
const heldRequestId = 'req-7f3a';

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

/// Opens the held save of [story] in place, to its details.
Future<void> openHeldSave(WidgetTester tester, String story) async {
  final open = find.byKey(Key('held-save-open ${heldSaveId(story)}'));
  await tester.ensureVisible(open);
  await tester.pump();
  await tester.tap(open);
  await World.settle(tester);
}
