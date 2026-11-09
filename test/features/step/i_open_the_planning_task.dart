import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I open the planning task {name}
Future<void> iOpenThePlanningTask(WidgetTester tester, String name) async {
  await tapPlanning(tester, planningElement('task $name'));
}
