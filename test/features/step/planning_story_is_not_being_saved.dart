import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} is not being saved
Future<void> planningStoryIsNotBeingSaved(WidgetTester tester, String id) async {
  // Keeping the card's saving line after the planner answered or refused makes this fail.
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('Saving…')), findsNothing);
}
