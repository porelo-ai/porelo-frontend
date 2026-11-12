import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: I order the work and start its builder task
Future<void> iOrderTheWorkAndStartItsBuilderTask(WidgetTester tester) =>
    walked(tester, '6 the person orders the work and starts its builder task', () async {
      await noteTheTasks();
      await tester.tap(find.byKey(const Key('story-work-start')));
      await pumpFor(tester);
      final dialog = find.byKey(const Key('story-work-dialog'));
      final refused = find.byKey(const Key('story-work-error'));
      // The form closes once each task it ordered was started.
      await pumpUntil(
        tester,
        () => dialog.evaluate().isEmpty || refused.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 10),
        what: 'the work to be ordered and started',
      );
      if (refused.evaluate().isNotEmpty) fail('the start was refused: ${tester.widget<Text>(refused).data}');
      // One builder for each issue, each in the issue's repository.
      Walk.builders = [
        for (final each in await theNewTasks(tester, 'the builder tasks', Walk.issues.length)) theContainerOf(each),
      ];
      noteStep('   the builders run in ${Walk.builders.join(', ')}');
      // The readers are offered once the builders end, and found as the tasks after them.
      Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.builders};
    });
