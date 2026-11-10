import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I review that work at the gate
Future<void> iReviewThatWorkAtTheGate(WidgetTester tester) => pictured(tester, () async {
  // Waiting work is answered under Needs you, from its row there.
  final tile = theRowOf(Rehearsal.waitingTask!);
  await toThePlace(tester, 'attention');
  await pumpUntil(
    tester,
    () => tile.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the row of ${Rehearsal.waitingTask} under Needs you',
  );
  await tester.ensureVisible(tile.first);
  final review = find.descendant(of: tile.first, matching: find.text('Review at the gate'));
  if (review.evaluate().isEmpty) {
    // Folded, the row shows its work alone; unfolded, its answers.
    await tester.tap(tile.first);
    await pumpFor(tester);
  }
  await pumpUntil(
    tester,
    () => review.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'its review to be offered',
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
