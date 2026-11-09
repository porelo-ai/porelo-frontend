import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: a task of the project on the host has work waiting at its gate
Future<void> aTaskOfTheProjectOnTheHostHasWorkWaitingAtItsGate(WidgetTester tester) => pictured(tester, () async {
  // The tasks work by themselves; this waits, as the host says it, for the first of them to push to its gate.
  await pumpUntil(
    tester,
    () async {
      for (final task in await theProjectsTasksOnTheHost()) {
        if ((task['waiting'] as int? ?? 0) > 0) {
          Rehearsal.waitingTask = task['name'] as String;
          return true;
        }
      }
      return false;
    },
    timeout: const Duration(minutes: 30),
    what: 'a task of ${Rehearsal.project} to push to its gate',
  );
});
