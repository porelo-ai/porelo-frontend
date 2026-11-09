import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I open the planning web link {label}
Future<void> iOpenThePlanningWebLink(WidgetTester tester, String label) async {
  await openPlanningBrowser(tester, label);
}
