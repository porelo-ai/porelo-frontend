import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the machine does not offer planning
Future<void> theMachineDoesNotOfferPlanning(WidgetTester tester) async {
  expect(planningElement('no-planning'), findsOneWidget);
  expect(planningText(tester, planningElement('no-planning')), contains('does not offer planning'));
  expect(planningElement('priority'), findsNothing);
  expect(planningElement('search'), findsNothing);
}
