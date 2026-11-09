import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: planning detail reads are refused
Future<void> planningDetailReadsAreRefused(WidgetTester tester) async {
  refusePlanningDetails();
}
