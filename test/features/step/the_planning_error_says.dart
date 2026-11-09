import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning error says {words}
Future<void> thePlanningErrorSays(WidgetTester tester, String words) async {
  expect(words, isNotEmpty);
  expect(planningText(tester, planningElement('error')), contains(words));
}
