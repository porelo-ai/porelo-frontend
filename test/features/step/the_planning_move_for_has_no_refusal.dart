import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move for {id} has no refusal
Future<void> thePlanningMoveForHasNoRefusal(WidgetTester tester, String id) async {
  expect(planningElement('move-pending $id'), findsOneWidget);
  expect(planningElement('move-problem $id'), findsNothing);
}
