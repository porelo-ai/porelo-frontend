import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: planning story {id} is not being saved
Future<void> planningStoryIsNotBeingSaved(WidgetTester tester, String id) async {
  // A phase builds only the cards in its view: the card is brought into it first.
  await revealPlanning(tester, planningElement('card $id'));
  expect(planningElement('card $id'), findsOneWidget);
  // Keeping the card's saving line after the planner answered or refused makes this fail.
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('Saving…')), findsNothing);
}
