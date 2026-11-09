import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: only the searched planning story remains
Future<void> onlyTheSearchedPlanningStoryRemains(WidgetTester tester) async {
  final cards = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('planning-card '),
  );
  expect(cards, findsOneWidget);
  expect(planningElement('card ST291'), findsOneWidget);
}
