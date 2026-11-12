import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue table is shown
Future<void> thePlanningIssueTableIsShown(WidgetTester tester) async {
  final table = find.descendant(of: planningElement('detail'), matching: find.byType(DataTable));
  expect(table, findsOneWidget);
  expect(tester.widget<DataTable>(table).rows, hasLength(16));
  for (final label in ['Issue', 'Title', 'Repository', 'Size', 'State']) {
    expect(find.descendant(of: table, matching: find.text(label)), findsOneWidget);
  }
}
