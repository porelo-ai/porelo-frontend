import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} is being saved
Future<void> planningStoryIsBeingSaved(WidgetTester tester, String id) async {
  // Dropping the card's saving line while the planner has not answered makes this fail.
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('Saving…')), findsOneWidget);
}
