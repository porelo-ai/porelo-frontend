import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: closed planning states are shown
Future<void> closedPlanningStatesAreShown(WidgetTester tester) async {
  expect(planningElement('state Finished'), findsOneWidget);
  expect(planningElement('state Rejected'), findsOneWidget);
  expect(planningElement('card ST264'), findsOneWidget);
}
