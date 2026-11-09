import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning drop hint names {state}
Future<void> noPlanningDropHintNames(WidgetTester tester, String state) async {
  // Accepting a card over its current displayed state makes the hover hint appear and fails this check.
  expect(
    find.descendant(of: planningElement('state $state'), matching: find.text('Drop here for $state')),
    findsNothing,
  );
}
