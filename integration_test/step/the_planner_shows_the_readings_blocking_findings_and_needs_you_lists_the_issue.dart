import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';
import '../support/results_land.dart';

/// Usage: the planner shows the reading's blocking findings and Needs you lists the issue
Future<void> thePlannerShowsTheReadingsBlockingFindingsAndNeedsYouListsTheIssue(WidgetTester tester) => walked(
  tester,
  "11 [findings] read: the planner shows the reading's blocking findings and Needs you lists the issue",
  () async {
    // The reader's answer ends in its Findings block, which the planner judges and keeps in its own work record, not in
    // Git. A blocking one stops the reading: the issue stays in Reading, nobody at work, under Needs you.
    ResultsLand.blocked = [];
    await pumpUntil(
      tester,
      () async => (await theBlockedIssues()).isNotEmpty,
      timeout: const Duration(minutes: 2),
      what: 'the planner to stop a reading of ${Walk.story} on blocking findings',
    );
    await toThePlace(tester, 'attention');
    for (final issue in ResultsLand.blocked) {
      final entry = theEntryOf(issue.id);
      await pumpUntil(
        tester,
        () => entry.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: '${issue.id} under what needs a person',
      );
      // The findings the planner shows, blocking first, read from its record of the reading.
      final blocking = find.descendant(
        of: entry,
        matching: find.textContaining(RegExp('^blocking', caseSensitive: false)),
      );
      await pumpUntil(
        tester,
        () => blocking.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 1),
        what: "the reader's blocking findings of ${issue.id} under its entry",
      );
      noteStep('   ${issue.id}: ${tester.widget<Text>(blocking.first).data}');
    }
  },
);
