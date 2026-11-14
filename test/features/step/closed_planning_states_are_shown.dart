import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: closed planning states are shown
Future<void> closedPlanningStatesAreShown(WidgetTester tester) async {
  expect(planningElement('state Finished'), findsOneWidget);
  expect(planningElement('state Rejected'), findsOneWidget);
  expect(planningElement('card ST264'), findsOneWidget);
  // Only an unfolded Done draws a closed story's card whole, with its title.
  expect(find.textContaining('A host prepared with no project or person'), findsOneWidget);
}
