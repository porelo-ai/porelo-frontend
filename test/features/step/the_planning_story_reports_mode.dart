import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story reports mode {mode}
Future<void> thePlanningStoryReportsMode(WidgetTester tester, String mode) async {
  reportPlanningMode(mode);
}
