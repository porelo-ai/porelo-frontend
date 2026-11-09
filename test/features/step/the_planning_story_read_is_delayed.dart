import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story read is delayed
Future<void> thePlanningStoryReadIsDelayed(WidgetTester tester) async {
  delayPlanningStory();
}
