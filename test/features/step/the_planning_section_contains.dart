import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning section {title} contains {words}
Future<void> thePlanningSectionContains(WidgetTester tester, String title, String words) async {
  expectPlanningSection(tester, title, words);
}
