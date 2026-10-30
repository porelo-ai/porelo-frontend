import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the projects page lists {'checkout'} on {'this machine'}
///
/// Each project row retains its specific machine.
Future<void> theProjectsPageListsOn(WidgetTester tester, String project, String machine) async {
  final row = find.byKey(ValueKey<String>('projects-row $machine/$project'));
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.textContaining('on $machine')), findsOneWidget);
}
