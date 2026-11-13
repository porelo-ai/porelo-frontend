import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: I choose Rework for the stopped reading
Future<void> iChooseReworkForTheStoppedReading(WidgetTester tester) =>
    walked(tester, '12 [findings] the person chooses Rework for the stopped reading', () async {
      // The readers are no reworks: they were started before. A resume reads the blocked issues again.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.readers};
      final blocked = await theBlockedIssues();
      if (blocked.isEmpty) fail('asked the planner for an issue whose reading stopped on blocking findings; none');
      await toThePlace(tester, 'attention');
      for (final issue in blocked) {
        // Under the entry, as the planner's own row draws it; the blocking findings go with the rework.
        final choose = find.byKey(Key('reading-resolve ${issue.id} REWORK'));
        await pumpUntil(tester, () => choose.evaluate().isNotEmpty, what: 'Rework offered for ${issue.id}');
        await tester.ensureVisible(choose.first);
        await tester.tap(choose.first);
        await pumpFor(tester);
        final send = find.byKey(const Key('reading-rework-send'));
        await pumpUntil(tester, () => send.evaluate().isNotEmpty, what: 'the Rework dialog for ${issue.id}');
        await tester.tap(send);
        await pumpFor(tester);
        noteStep('   ${issue.id}: rework chosen');
      }
    });
