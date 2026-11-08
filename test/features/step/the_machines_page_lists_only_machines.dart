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
    expect(railEntryFor(machine.name), findsOneWidget);
  }
  expect(find.byKey(const Key('facts-page')), findsOneWidget);
  final projects = find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('project '),
  );
  expect(projects, findsNothing);
  expect(workRows(), findsNothing);
}
