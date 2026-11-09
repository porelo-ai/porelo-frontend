import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I open planning story {id}
Future<void> iOpenPlanningStory(WidgetTester tester, String id) async {
  await tapPlanning(tester, planningElement('story $id'));
}
