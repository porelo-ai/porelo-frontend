import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning asks to wait for the save
Future<void> planningAsksToWaitForTheSave(WidgetTester tester) async {
  // Leaving without a question, stacking a second one, or offering to leave while the save is out makes this fail.
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(find.text('Planning is saving'), findsOneWidget);
  expect(planningElement('stay'), findsOneWidget);
  expect(planningElement('leave'), findsNothing);
}
