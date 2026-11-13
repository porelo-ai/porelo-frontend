import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e.dart';

/// What the story of work moving on by itself shares between its steps.
abstract final class PlannerMoves {
  /// The tasks porelo listed before the person opened the Needs-you entry.
  static Set<String> tasksBeforeOpening = {};
}

/// The entry of issue [issue] under what needs a person: a row of its own that names it.
Finder theEntryOf(String issue) => find.ancestor(
  of: find.textContaining(issue),
  matching: find.byWidgetPredicate(
    (widget) => widget.key is ValueKey && '${(widget.key! as ValueKey).value}'.startsWith('attention-row '),
  ),
);

/// The first of the reader's blocking findings the entry of [issue] shows under what needs a person, once it does: a
/// reading stopped on them is listed there with the findings the planner keeps from the reader's answer.
Future<String> theBlockingFindingsUnder(WidgetTester tester, String issue) async {
  await toThePlace(tester, 'attention');
  final entry = theEntryOf(issue);
  await pumpUntil(
    tester,
    () => entry.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: '$issue under what needs a person',
  );
  final blocking = find.descendant(of: entry, matching: find.textContaining(RegExp('^blocking', caseSensitive: false)));
  await pumpUntil(
    tester,
    () => blocking.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 1),
    what: "the reader's blocking findings of $issue under its entry",
  );
  return tester.widget<Text>(blocking.first).data ?? '';
}

/// Chooses Rework for the stopped reading of [issue] on its entry under what needs a person, as the planner's own row
/// draws it, and sends the Rework dialog as it opens: the blocking findings go with the rework.
Future<void> chooseRework(WidgetTester tester, String issue) async {
  await toThePlace(tester, 'attention');
  final choose = find.byKey(Key('reading-resolve $issue REWORK'));
  await pumpUntil(tester, () => choose.evaluate().isNotEmpty, what: 'Rework offered for $issue');
  await tester.ensureVisible(choose.first);
  await tester.tap(choose.first);
  await pumpFor(tester);
  final send = find.byKey(const Key('reading-rework-send'));
  await pumpUntil(tester, () => send.evaluate().isNotEmpty, what: 'the Rework dialog for $issue');
  // Ready once the Reworking rule was read and a way to rework it chosen: the dialog's defaults.
  bool offered() => send.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(send.first).onPressed != null;
  try {
    await pumpUntil(
      tester,
      offered,
      timeout: const Duration(minutes: 1),
      what: 'Rework offered in the dialog for $issue',
    );
  } on TestFailure {
    final said = find.byKey(const Key('reading-rework-no-agent'));
    fail(
      'the Rework dialog for $issue never let Rework be sent: '
      '${said.evaluate().isEmpty ? 'no agent or way of working was chosen' : tester.widget<Text>(said.first).data}',
    );
  }
  await tester.tap(send.first);
  await pumpFor(tester);
  await pumpUntil(tester, () => send.evaluate().isEmpty, what: 'the Rework dialog for $issue to close once sent');
}
