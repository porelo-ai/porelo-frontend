import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I start work on every repository of the project at once
Future<void> iStartWorkOnEveryRepositoryOfTheProjectAtOnce(WidgetTester tester) => pictured(tester, () async {
  await toTheProjectOnTheHost(tester);
  // Offered only where a repository's project.yml names an agent; the rehearsal's project, signed by the operator,
  // names none yet, and that is said rather than failed.
  if (await theMenuItemIsHeldBack(tester, find.byKey(const Key('project-menu')), 'Start an agent for each repository…')
      case final why?) {
    return notRunBecause('the project menu holds back a start for every repository: $why');
  }
  await chooseFromTheMenu(tester, find.byKey(const Key('project-menu')), 'Start an agent for each repository…');
  // Which repositories, then the sign-ins, each held until the machine has answered; then the check and Start.
  final next = find.byKey(const Key('wizard-next'));
  final start = find.byKey(const Key('start-it'));
  bool enabled(Finder button) =>
      button.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(button.first).onPressed != null;
  while (start.evaluate().isEmpty) {
    await pumpUntil(
      tester,
      () => enabled(next) || start.evaluate().isNotEmpty,
      timeout: const Duration(minutes: 3),
      what: 'the batch to go on',
    );
    if (start.evaluate().isNotEmpty) break;
    await tester.tap(next.first);
    await pumpFor(tester);
  }
  await pumpUntil(tester, () => enabled(start), timeout: const Duration(minutes: 3), what: 'the batch to offer Start');
  await noteTheHostsTasks();
  await tester.tap(start.first);
  await pumpFor(tester);
  // Its last step holds Finish until every start has its answer.
  final finish = find.ancestor(of: find.text('Finish'), matching: find.byKey(const Key('wizard-next')));
  await pumpUntil(
    tester,
    () => finish.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(finish.first).onPressed != null,
    timeout: const Duration(minutes: 15),
    what: 'the batch to finish',
  );
  // Each start's answer, in the machine's words, is on this page alone: kept in the run's log before it closes.
  final shown = tester.widgetList<Text>(find.byType(Text)).map((each) => each.data).nonNulls.join(' | ');
  debugPrint('the batch answered: $shown');
  await tester.tap(finish.first);
  await pumpFor(tester);
});
