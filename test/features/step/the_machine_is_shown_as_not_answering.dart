import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machine is shown as not answering
Future<void> theMachineIsShownAsNotAnswering(WidgetTester tester) async {
  // On the list of machines, where each row says how it stands.
  await lookingAtTheMachines(tester, () async {
    final said = whatTheMachinesRowSays(tester, World.machines.current.name);
    expect(said, contains('Not answering'), reason: 'its row says: $said');
  });
}

/// Everything the row of [machine] on the Machines page says, as one line.
String whatTheMachinesRowSays(WidgetTester tester, String machine) {
  final row = railEntryFor(machine);
  expect(row, findsOneWidget, reason: '$machine is not among the machines');
  final semantics = find.ancestor(of: row, matching: find.byType(Semantics)).first;
  return [
    tester.widget<Semantics>(semantics).properties.label ?? '',
    for (final text in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))))
      text.data ?? text.textSpan?.toPlainText() ?? '',
    for (final tooltip in tester.widgetList<Tooltip>(find.descendant(of: row, matching: find.byType(Tooltip))))
      tooltip.message ?? '',
  ].join(' ');
}
