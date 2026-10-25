import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: the projects page lists {'checkout'} on {'this machine'}
///
/// Once, whatever machines it is on, saying which.
Future<void> theProjectsPageListsOn(WidgetTester tester, String project, String machine) async {
  await expandListRows(tester);
  final row = find.byKey(ValueKey<String>('projects-row $project'));
  expect(row, findsOneWidget);
  final on = tester.widget<Text>(find.descendant(of: row, matching: find.byKey(const Key('projects-row-machines'))));
  expect(on.data, contains(machine));
}
