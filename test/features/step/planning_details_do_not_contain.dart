import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: planning details do not contain {words}
Future<void> planningDetailsDoNotContain(WidgetTester tester, String words) async {
  expectPlanningDetail(words, present: false);
}
