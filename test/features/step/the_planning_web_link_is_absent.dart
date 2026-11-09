import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning web link {label} is absent
Future<void> thePlanningWebLinkIsAbsent(WidgetTester tester, String label) async {
  final detail = planningElement('detail');
  expect(detail, findsOneWidget);
  expect(find.descendant(of: detail, matching: find.widgetWithText(OutlinedButton, label)), findsNothing);
}
