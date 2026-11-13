import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning warns that {id} carries issues along
Future<void> planningWarnsThatCarriesIssuesAlong(WidgetTester tester, String id) async {
  // Saving a story move that carries issues along without asking makes this fail.
  expect(planningElement('move-warning'), findsOneWidget);
  expect(find.byKey(Key('planning-move-warning-item ISSUES_ALONG $id')), findsOneWidget);
  expect(planningElement('move-confirm'), findsOneWidget);
}
