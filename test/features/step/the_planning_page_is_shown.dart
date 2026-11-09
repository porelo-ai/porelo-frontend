import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

import 'package:porelo_frontend/src/ui/planning_view.dart';

/// Usage: the planning page is shown
Future<void> thePlanningPageIsShown(WidgetTester tester) async {
  // Navigating away despite canceling the question makes this fail.
  expect(find.byType(PlanningView), findsOneWidget);
  expect(planningElement('search'), findsOneWidget);
}
