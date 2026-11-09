import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning start was requested for {id} in {state}
Future<void> planningStartWasRequestedForIn(WidgetTester tester, String id, String state) async {
  expect(planningElement('start-request'), findsNothing);
  expect(find.byKey(const Key('story-work-dialog')), findsOneWidget);
  expect(find.textContaining(id), findsWidgets);
  expect(find.textContaining(state), findsWidgets);
}
