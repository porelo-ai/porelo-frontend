import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I open the planning owner story
Future<void> iOpenThePlanningOwnerStory(WidgetTester tester) async {
  await tapPlanning(tester, planningElement('owner-story'));
}
