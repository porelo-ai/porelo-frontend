import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning breadcrumb is {path}
Future<void> thePlanningBreadcrumbIs(WidgetTester tester, String path) async {
  await expectPlanningCrumbs(tester, path);
}
