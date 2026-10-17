import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the log {'agent.log'} is described by nothing
Future<void> theLogIsDescribedByNothing(WidgetTester tester, String log) async {
  final tile = tester.widget<ListTile>(find.ancestor(of: find.text(log), matching: find.byType(ListTile)));
  // Nothing, and not a blank line: a name that speaks for itself needs no sentence, and an empty
  // one under it would read as a description that failed rather than one never given.
  expect(find.descendant(of: find.byWidget(tile), matching: find.byKey(const Key('what-the-log-holds'))), findsNothing);
}
