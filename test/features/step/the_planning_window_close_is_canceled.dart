import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/planning_view.dart';

/// Usage: the planning window close is canceled
Future<void> thePlanningWindowCloseIsCanceled(WidgetTester tester) async {
  // Continuing to the quit dialog after Keep editing makes the first assertion fail.
  expect(find.byType(AlertDialog), findsNothing);
  // Removing the Planning page after cancellation makes the second assertion fail.
  expect(find.byType(PlanningView), findsOneWidget);
}
