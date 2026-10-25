import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: the card of {'checkout'} lists the machines {'this machine, elsewhere'}
///
/// A project is listed once on the projects page, saying every machine it is on.
Future<void> theCardOfListsTheMachines(WidgetTester tester, String project, String machines) async {
  await expandListRows(tester);
  final row = find.byKey(ValueKey<String>('projects-row $project'));
  expect(row, findsOneWidget, reason: '$project is not listed once');
  final on = tester.widget<Text>(find.descendant(of: row, matching: find.byKey(const Key('projects-row-machines'))));
  for (final machine in machines.split(',').map((each) => each.trim())) {
    expect(on.data, contains(machine), reason: '$project does not say it is on $machine');
  }
}
