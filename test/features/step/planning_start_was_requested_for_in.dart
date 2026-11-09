import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning start was requested for {id} in {state}
Future<void> planningStartWasRequestedForIn(WidgetTester tester, String id, String state) async {
  // Removing the WORKING handler or its shell feedback makes this fail; so does requesting a wrong story or state.
  expect(planningText(tester, planningElement('start-request')), '$id → $state');
}
