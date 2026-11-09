import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning detail error is {words}
Future<void> thePlanningDetailErrorIs(WidgetTester tester, String words) async {
  expect(planningText(tester, planningElement('detail-error')), contains(words));
}
