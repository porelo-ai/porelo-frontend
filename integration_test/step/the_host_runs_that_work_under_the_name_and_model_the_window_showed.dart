import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the host runs that work, under the name and model the window showed
Future<void> theHostRunsThatWorkUnderTheNameAndModelTheWindowShowed(WidgetTester tester) => pictured(tester, () async {
  final repository = Rehearsal.startedRepository!;
  Map<String, dynamic>? task;
  await pumpUntil(
    tester,
    () async {
      // Only a task this start made: the run's earlier steps may leave tasks running on the same repository.
      for (final each in await theTasksStartedSince()) {
        if (each['repository'] == repository && each['running'] == true) task = each;
      }
      return task != null;
    },
    timeout: const Duration(minutes: 5),
    what: 'the host to run work on $repository',
  );
  // Each said by the host, or the run fails: a host that does not say is not one that agrees.
  final display = task!['display'], named = task!['named'], model = task!['model'];
  expect(display, isA<String>(), reason: 'the host says what the task is shown as');
  expect(named, isA<String>(), reason: 'the host says the name its start was given');
  expect(model, isA<String>(), reason: 'the host says the model, "" for the default');
  final name = Rehearsal.startedName!;
  if (name.isEmpty) {
    expect(named, '', reason: 'no name was given, so the host named it itself');
  } else {
    expect(display, name, reason: 'the name the window sent');
  }
  expect(model, Rehearsal.startedModel, reason: 'the model the window showed, "" for the default');
  await toThePlace(tester, 'work');
  await pumpUntil(
    tester,
    () => find.textContaining(display as String).evaluate().isNotEmpty,
    what: 'Work to show $display',
  );
});
