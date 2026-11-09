import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: Planning is selected in the rail
Future<void> planningIsSelectedInTheRail(WidgetTester tester) async {
  expectPlanningRail(tester);
}
