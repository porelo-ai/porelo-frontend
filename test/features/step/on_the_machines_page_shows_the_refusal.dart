import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: on the machines page {'build'} shows the refusal {'porelo-build accepted none of the keys your ssh agent offered'}
Future<void> onTheMachinesPageShowsTheRefusal(WidgetTester tester, String name, String words) async {
  await lookingAtTheMachines(tester, () async {
    final row = find.byKey(ValueKey<String>('machines-row $name'));
    final heading = find.descendant(of: row, matching: find.byKey(ValueKey<String>('rail-machine $name')));
    expect(heading, findsOneWidget);
    // Beside the machine, on its own row, without opening anything.
    expect(find.descendant(of: row, matching: find.textContaining(words)), findsOneWidget);
  });
}
