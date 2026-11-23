import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: planning story {id} is being saved
Future<void> planningStoryIsBeingSaved(WidgetTester tester, String id) async {
  // The board builds only the cards in view.
  await revealPlanning(tester, planningElement('card $id'));
  // Dropping the card's saving line while the planner has not answered makes this fail.
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('Saving…')), findsOneWidget);
}
