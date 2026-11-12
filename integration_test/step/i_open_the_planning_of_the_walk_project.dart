import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: I open the planning of the walk project
Future<void> iOpenThePlanningOfTheWalkProject(WidgetTester tester) =>
    walked(tester, '1 the window opens the planning of ${Walk.project}', () async {
      await toThePlace(tester, 'planning');
      final board = find.text('The stories of project ${Walk.project} by state, the most important first.');
      final field = find.byKey(const Key('planning-project'));
      // The window starts the planner itself, which takes a while on a fresh account.
      await pumpUntil(
        tester,
        () => board.evaluate().isNotEmpty || field.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'the planning of a project',
      );
      if (board.evaluate().isEmpty) {
        await tester.tap(field.first);
        await pumpFor(tester);
        await tester.tap(find.text(Walk.project).last);
        await pumpFor(tester);
      }
      await pumpUntil(
        tester,
        () => board.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'the board of ${Walk.project}',
      );
      // The heading stands before the planner has read the project; its first answer is what the steps build on.
      final waiting = find.text('Waiting for the planner’s answer.');
      await pumpUntil(
        tester,
        () => waiting.evaluate().isEmpty,
        timeout: const Duration(minutes: 5),
        what: 'the planner to answer for the board of ${Walk.project}',
      );
    });
