import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I use a narrow planning pane
Future<void> iUseANarrowPlanningPane(WidgetTester tester) async {
  await narrowPlanningPane(tester);
}
