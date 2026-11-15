import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning warns that {id} carries issues along whose files are deleted
Future<void> planningWarnsThatCarriesIssuesAlongWhoseFilesAreDeleted(WidgetTester tester, String id) async {
  // A screen that finishes a story over its issues without naming them, or without saying their files go, fails here.
  expect(planningElement('move-warning'), findsOneWidget);
  final item = find.byKey(Key('planning-move-warning-item ISSUES_ALONG $id'));
  expect(item, findsOneWidget);
  expect(tester.widget<Text>(item).data, contains('their files are deleted as each is closed'));
  expect(planningElement('move-confirm'), findsOneWidget);
}
