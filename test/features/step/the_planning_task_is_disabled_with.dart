import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning task {name} is disabled with {reason}
Future<void> thePlanningTaskIsDisabledWith(WidgetTester tester, String name, String reason) async {
  await expectPlanningTask(tester, name, reason);
}
