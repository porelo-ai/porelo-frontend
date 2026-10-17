import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the logs offered are {'agent.log'}
Future<void> theLogsOfferedAre(WidgetTester tester, String logs) async {
  // What the daemon said the task has, and nothing this end decided: a task with no gate has no
  // gate.log, so a list held here would offer a file that was never going to exist.
  final offered = tester
      .widgetList<ListTile>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ListTile)))
      .map((tile) => (tile.title! as Text).data)
      .join(', ');
  expect(offered, logs);
}
