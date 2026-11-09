import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move for {id} says {words}
Future<void> thePlanningMoveForSays(WidgetTester tester, String id, String words) async {
  expect(planningText(tester, planningElement('move-problem $id')), contains(words));
}
