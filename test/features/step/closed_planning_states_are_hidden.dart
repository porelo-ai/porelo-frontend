import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: closed planning states are hidden
Future<void> closedPlanningStatesAreHidden(WidgetTester tester) async {
  expect(planningElement('state Finishing'), findsOneWidget);
  expect(planningElement('state Finished'), findsNothing);
  expect(planningElement('state Rejected'), findsNothing);
  expect(find.text('Show Finished and Rejected (3)'), findsOneWidget);
}
