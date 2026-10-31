import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machine is shown as not answering
Future<void> theMachineIsShownAsNotAnswering(WidgetTester tester) async {
  // On the list of machines, where each row says how it stands.
  await lookingAtTheMachines(tester, () async {
    final said = whatTheMachinesRowSays(tester, World.machines.current.name);
    expect(said, contains('Not connected'), reason: 'its row says: $said');
  });
}

/// Everything the row of [machine] on the Machines page says, as one line.
String whatTheMachinesRowSays(WidgetTester tester, String machine) {
  final row = find.byKey(ValueKey<String>('machines-row $machine'));
  expect(row, findsOneWidget, reason: '$machine is not among the machines');
  return [
    for (final text in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))))
      text.data ?? text.textSpan?.toPlainText() ?? '',
  ].join(' ');
}
