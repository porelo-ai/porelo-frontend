import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning build stories are sorted
Future<void> thePlanningBuildStoriesAreSorted(WidgetTester tester) async {
  final state = find.byKey(const Key('planning-state Implementing'), skipOffstage: false);
  expect(state, findsOneWidget);
  // The phase builds only the cards in its view: its cards are read in order as it is walked from top to foot.
  final cards = find.descendant(of: state, matching: find.byWidgetPredicate((widget) => widget is Card));
  final seen = <String>[];
  await walkPlanning(tester, only: planningPhaseHolding(tester, state), () {
    for (final card in tester.widgetList<Card>(cards)) {
      final key = (card.key! as ValueKey<String>).value;
      if (!seen.contains(key)) seen.add(key);
    }
    return false;
  });
  expect(seen, [
    'planning-card ST5',
    'planning-card ST12',
    'planning-card ST27',
    'planning-card ST127',
    'planning-card ST193',
  ]);
}
