import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: planning details contain {words}
Future<void> planningDetailsContain(WidgetTester tester, String words) async {
  expectPlanningDetail(words);
}
