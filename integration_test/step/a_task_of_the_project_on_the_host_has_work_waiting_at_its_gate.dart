import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: a task of the project on the host has work waiting at its gate
Future<void> aTaskOfTheProjectOnTheHostHasWorkWaitingAtItsGate(WidgetTester tester) => pictured(tester, () async {
  // No other task is asked to push: this one is, from the window, unattended, under a name no other start used.
  final carried = await theCarriedRepositories();
  expect(carried, isNotEmpty, reason: 'the host carries a repository of ${Rehearsal.project}');
  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  await startWorkOn(
    tester,
    carried.first,
    name: 'gate-$stamp',
    prompt:
        'Add the file rehearsal-gate-$stamp.txt with the single line "rehearsal $stamp", commit it on your branch '
        'and push it as your Porelo guide says. Change nothing else.',
  );
  // It works by itself; this waits, as the host says it, for it to push to its gate.
  await pumpUntil(
    tester,
    () async {
      for (final task in await theTasksStartedSince()) {
        if ((task['waiting'] as int? ?? 0) > 0) {
          Rehearsal.waitingTask = task['name'] as String;
          return true;
        }
      }
      return false;
    },
    timeout: const Duration(minutes: 30),
    what: 'the task started on ${carried.first} to push to its gate',
  );
});
