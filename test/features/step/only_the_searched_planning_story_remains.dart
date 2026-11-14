import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: only the searched planning story remains
Future<void> onlyTheSearchedPlanningStoryRemains(WidgetTester tester) async {
  final cards = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('planning-card '),
  );
  // Each phase builds only the cards in its view: every card shown anywhere is gathered as the phases are walked.
  final seen = <String>{};
  await walkPlanning(tester, () {
    seen.addAll([for (final card in cards.evaluate()) (card.widget.key! as ValueKey<String>).value]);
    return false;
  });
  expect(seen, {'planning-card ST291'});
  await revealPlanning(tester, planningElement('card ST291'));
  expect(planningElement('card ST291'), findsOneWidget);
}
