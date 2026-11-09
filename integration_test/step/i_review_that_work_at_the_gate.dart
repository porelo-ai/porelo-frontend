import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I review that work at the gate
Future<void> iReviewThatWorkAtTheGate(WidgetTester tester) => pictured(tester, () async {
  // Waiting work is answered under Needs you, from its tile there.
  final tile = theTileOf(Rehearsal.waitingTask!);
  await toThePlace(tester, 'attention');
  await pumpUntil(
    tester,
    () => tile.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the tile of ${Rehearsal.waitingTask}',
  );
  await tester.ensureVisible(tile.first);
  final review = find.descendant(of: tile.first, matching: find.text('Review at the gate'));
  if (review.evaluate().isEmpty) {
    // Folded, the tile shows its work alone; unfolded, its answers.
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
