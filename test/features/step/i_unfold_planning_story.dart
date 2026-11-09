import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I unfold planning story {id}
Future<void> iUnfoldPlanningStory(WidgetTester tester, String id) async {
  await tapPlanning(tester, planningElement('expand $id'));
}
