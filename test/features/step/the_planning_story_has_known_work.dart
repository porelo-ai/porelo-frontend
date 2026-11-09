import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story has known work
Future<void> thePlanningStoryHasKnownWork(WidgetTester tester) async {
  reportPlanningWork(true);
}
