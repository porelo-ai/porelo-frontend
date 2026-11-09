import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning message {words} appears once
Future<void> thePlanningMessageAppearsOnce(WidgetTester tester, String words) async {
  expectPlanningMessageOnce(words);
}
