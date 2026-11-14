import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: this computer offers no SSH Console
Future<void> thisComputerOffersNoSshConsole(WidgetTester tester) async {
  final machine = World.machines.current.name;
  await toTheMachines(tester);
  await World.tapInView(tester, 'rail ${ShellPlace.machineKey(machine)}');
  expect(
    find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(machine)} ${MachineSection.managing.name}')),
    findsOneWidget,
    reason: 'its sections are shown',
  );
  expect(
    find.byKey(ValueKey<String>('rail ${ShellPlace.machineKey(machine)} ${MachineSection.console.name}')),
    findsNothing,
  );
}
