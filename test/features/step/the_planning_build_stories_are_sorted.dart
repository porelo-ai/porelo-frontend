import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning build stories are sorted
Future<void> thePlanningBuildStoriesAreSorted(WidgetTester tester) async {
  final state = planningElement('state Implementing');
  expect(state, findsOneWidget);
  final cards = find.descendant(of: state, matching: find.byWidgetPredicate((widget) => widget is Card));
  expect(tester.widgetList<Card>(cards).map((card) => (card.key! as ValueKey<String>).value).toList(), [
    'planning-card ST5',
    'planning-card ST12',
    'planning-card ST27',
    'planning-card ST127',
    'planning-card ST193',
  ]);
}
