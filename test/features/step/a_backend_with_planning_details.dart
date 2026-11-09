import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: a backend with planning details
Future<void> aBackendWithPlanningDetails(WidgetTester tester) async {
  await startPlanningDetails(tester);
}
