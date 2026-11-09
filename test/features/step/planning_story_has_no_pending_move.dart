import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} has no pending move
Future<void> planningStoryHasNoPendingMove(WidgetTester tester, String id) async {
  expect(planningElement('pending $id'), findsNothing);
  expect(planningElement('undo $id'), findsNothing);
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('moved')), findsNothing);
}
