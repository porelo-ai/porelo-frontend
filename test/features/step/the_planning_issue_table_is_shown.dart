import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning issue table is shown
///
/// The story's issues stand in one table per state group; together they hold all of them, each table with every column.
Future<void> thePlanningIssueTableIsShown(WidgetTester tester) async {
  final tables = find.descendant(of: planningElement('detail'), matching: find.byType(DataTable));
  expect(tables, findsWidgets);
  final shown = tester.widgetList<DataTable>(tables).toList();
  expect(shown.fold<int>(0, (sum, table) => sum + table.rows.length), 16);
  for (final label in ['Issue', 'Title', 'Repository', 'Size', 'Left', 'Who']) {
    expect(find.descendant(of: tables, matching: find.text(label)), findsNWidgets(shown.length));
  }
}
