import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../../support/expand_list_rows.dart';

/// Usage: on the machines page {'build'} shows the refusal {'porelo-build accepted none of the keys your ssh agent offered'}
Future<void> onTheMachinesPageShowsTheRefusal(WidgetTester tester, String name, String words) async {
  await lookingAtTheMachines(tester, () async {
    final row = find.byKey(ValueKey<String>('machines-row $name'));
    await expandListRows(tester, within: row);
    final heading = find.descendant(of: row, matching: find.byKey(ValueKey<String>('rail-machine $name')));
    final refused = find.descendant(of: row, matching: find.byKey(ValueKey<String>('machine-refused $name')));
    expect(heading, findsOneWidget);
    expect(refused, findsOneWidget);
    expect(tester.widget<Text>(refused).data, contains(words));
  });
}
