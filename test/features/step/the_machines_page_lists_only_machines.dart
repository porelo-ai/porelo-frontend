import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machines page lists only machines
///
/// Each machine is a row; its projects and its work are under Projects and Work, never here.
Future<void> theMachinesPageListsOnlyMachines(WidgetTester tester) async {
  await toTheMachines(tester);
  for (final machine in World.machines.all) {
    expect(find.byKey(ValueKey<String>('machines-row ${machine.name}')), findsOneWidget);
  }
  final projects = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('project '),
  );
  expect(projects, findsNothing);
  expect(find.byWidgetPredicate((widget) => widget is Card && '${widget.key}'.contains("'tile ")), findsNothing);
}
