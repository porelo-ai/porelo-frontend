import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I scroll the planning board
Future<void> iScrollThePlanningBoard(WidgetTester tester) async {
  await scrollPlanningBoard(tester);
}
