import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

import '../support/planning.dart';

/// Usage: the planning reading of {id} needs attention
Future<void> thePlanningReadingOfNeedsAttention(WidgetTester tester, String id) async {
  final reading = planningElement('reading $id');
  await revealPlanning(tester, reading);
  expect(reading, findsOneWidget);
  expect(tester.widget(reading), isA<TextButton>());
  expect(find.descendant(of: reading, matching: find.text('stopped in Reading - needs you')), findsOneWidget);
}
