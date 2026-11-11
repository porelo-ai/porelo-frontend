import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I review that work at the gate
Future<void> iReviewThatWorkAtTheGate(WidgetTester tester) => pictured(tester, () async {
  // A push at the gate is answered under Needs you, from its own row; never from the row of the work's end, whose
  // tap opens the task under Work instead.
  final row = theGateRowOf(Rehearsal.waitingTask!);
  final review = find.descendant(of: row, matching: find.byKey(const Key('gate-review')));
  await toThePlace(tester, 'attention');
  await pumpUntil(
    tester,
    () => review.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(review.first).onPressed != null,
    timeout: const Duration(minutes: 2),
    what: 'the review of ${Rehearsal.waitingTask} offered on its row under Needs you',
  );
  await tester.ensureVisible(review.first);
  await tester.tap(review.first);
  await pumpFor(tester);
  // The gate lists what waits there; its review opens from the push's row.
  final push = find.descendant(of: find.byType(GateView), matching: find.textContaining(' · waiting '));
  await pumpUntil(
    tester,
    () => push.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 1),
    what: 'the push at the gate',
  );
  await tester.tap(push.first);
  await pumpFor(tester);
  final commit = find.byKey(const Key('review-fact Commit'));
  final full = RegExp(r'\b[0-9a-f]{40}\b');
  await pumpUntil(
    tester,
    () => commit.evaluate().isNotEmpty && full.hasMatch(theWordsUnder(tester, commit.first)),
    timeout: const Duration(minutes: 1),
    what: 'the review to name its commit',
  );
  Rehearsal.reviewedCommit = full.firstMatch(theWordsUnder(tester, commit.first))!.group(0);
});
