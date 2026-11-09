import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning task {name} is available
Future<void> thePlanningTaskIsAvailable(WidgetTester tester, String name) async {
  await expectPlanningTask(tester, name, '');
}
