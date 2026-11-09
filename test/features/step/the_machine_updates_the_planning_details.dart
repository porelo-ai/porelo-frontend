import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine updates the planning details
Future<void> theMachineUpdatesThePlanningDetails(WidgetTester tester) async {
  await updatePlanningDetails(tester);
}
