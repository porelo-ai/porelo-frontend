import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning drop hint names {state}
Future<void> thePlanningDropHintNames(WidgetTester tester, String state) async {
  // Removing the candidate hint from DragTarget makes this fail during a held drag.
  expect(
    find.descendant(of: planningElement('state $state'), matching: find.text('Drop here for $state')),
    findsOneWidget,
  );
}
