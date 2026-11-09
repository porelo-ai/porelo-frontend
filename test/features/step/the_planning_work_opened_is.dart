import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning work opened is {name}
Future<void> thePlanningWorkOpenedIs(WidgetTester tester, String name) async {
  expectPlanningWorkOpened(tester, name);
}
