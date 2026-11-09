import 'package:flutter_test/flutter_test.dart';

import '../support/repository_said.dart';

/// Usage: the machine counts {'1'} running of {'1'} tasks in the repository {'payments-api'}
Future<void> theMachineCountsRunningOfTasksInTheRepository(
  WidgetTester tester,
  String running,
  String tasks,
  String repository,
) => theMachineSaysOfTheRepository(tester, repository, running: int.parse(running), tasks: int.parse(tasks));
