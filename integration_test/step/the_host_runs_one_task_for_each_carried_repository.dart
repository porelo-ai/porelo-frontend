import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the host runs one task for each carried repository
Future<void> theHostRunsOneTaskForEachCarriedRepository(WidgetTester tester) => pictured(tester, () async {
  if (Rehearsal.notRun != null) return;
  final carried = await theCarriedRepositoriesOnceSaid(tester);
  expect(carried, isNotEmpty);
  late Map<String, int> running;
  await pumpUntil(
    tester,
    () async {
      running = {for (final each in carried) each: 0};
      // Only the tasks this batch made: the run's earlier steps and scenarios may leave tasks running.
      for (final task in await theTasksStartedSince()) {
        final repository = task['repository'];
        if (task['running'] == true && running.containsKey(repository)) {
          running[repository as String] = running[repository]! + 1;
        }
      }
      return running.values.every((count) => count >= 1);
    },
    timeout: const Duration(minutes: 5),
    what: 'a task on every carried repository',
  );
  // One each: a second task on a repository is a start made twice.
  for (final MapEntry(:key, :value) in running.entries) {
    expect(value, 1, reason: key);
  }
});
