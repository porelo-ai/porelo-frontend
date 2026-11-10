import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planning.dart';

/// Usage: the planning page is shown
Future<void> thePlanningPageIsShown(WidgetTester tester) async {
  // Navigating away despite canceling the question makes this fail.
  expect(find.byType(PlanningScreen), findsOneWidget);
  expect(planningElement('search'), findsOneWidget);
}
