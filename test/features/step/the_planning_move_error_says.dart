import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move error says {words}
Future<void> thePlanningMoveErrorSays(WidgetTester tester, String words) async {
  expect(planningText(tester, planningElement('move-error')), contains(words));
}
