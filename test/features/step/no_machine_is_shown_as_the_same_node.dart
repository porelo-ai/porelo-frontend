import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: no machine is shown as the same node
Future<void> noMachineIsShownAsTheSameNode(WidgetTester tester) async {
  for (final machine in World.machines.all) {
    await toTheMachinesPage(tester, machine.name);
    final kind = tester.widget<Text>(find.byKey(const Key('machine-kind'))).data ?? '';
    expect(kind, isNot(contains('the same node as')), reason: machine.name);
  }
}
