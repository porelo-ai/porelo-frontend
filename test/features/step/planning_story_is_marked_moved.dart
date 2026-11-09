import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} is marked moved
Future<void> planningStoryIsMarkedMoved(WidgetTester tester, String id) async {
  // Removing the moved marker from an unfolded card makes this fail.
  // A story title may contain the word, so the marker is matched as its own text.
  expect(find.descendant(of: planningElement('card $id'), matching: find.text('moved')), findsOneWidget);
}
