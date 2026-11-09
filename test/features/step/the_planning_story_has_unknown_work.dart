import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story has unknown work
Future<void> thePlanningStoryHasUnknownWork(WidgetTester tester) async {
  reportPlanningWork(false);
}
