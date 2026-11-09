import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I press planning breadcrumb {index}
Future<void> iPressPlanningBreadcrumb(WidgetTester tester, num index) async {
  await tapPlanning(tester, planningElement('crumb ${index.toInt()}'));
}
