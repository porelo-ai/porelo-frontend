import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning asks before leaving
Future<void> planningAsksBeforeLeaving(WidgetTester tester) async {
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(planningElement('stay'), findsOneWidget);
  expect(planningElement('leave'), findsOneWidget);
}
