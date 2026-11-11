import 'package:flutter_test/flutter_test.dart';

import '../support/rehearsal.dart';

/// Usage: I start work on the first carried repository of the project
Future<void> iStartWorkOnTheFirstCarriedRepositoryOfTheProject(WidgetTester tester) => pictured(tester, () async {
  final carried = await theCarriedRepositories();
  expect(carried, isNotEmpty, reason: 'the host carries a repository of ${Rehearsal.project}');
  Rehearsal.startedRepository = carried.first;
  await startWorkOn(tester, carried.first);
});
