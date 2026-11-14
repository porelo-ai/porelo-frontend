import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

import '../support/planning.dart';

/// Usage: closed planning states are shown
Future<void> closedPlanningStatesAreShown(WidgetTester tester) async {
  for (final key in <String>['state Finished', 'state Rejected', 'card ST264']) {
    await revealPlanning(tester, planningElement(key));
    expect(planningElement(key), findsOneWidget);
  }
  // Only an unfolded Done draws a closed story's card whole, with its title.
  expect(find.textContaining('A host prepared with no project or person'), findsOneWidget);
}
