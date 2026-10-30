import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the card of {'checkout'} lists the machines {'this machine, elsewhere'}
///
/// A project has one independent row on each machine.
Future<void> theCardOfListsTheMachines(WidgetTester tester, String project, String machines) async {
  for (final machine in machines.split(',').map((each) => each.trim())) {
    final row = find.byKey(ValueKey<String>('projects-row $machine/$project'));
    expect(row, findsOneWidget, reason: '$project needs its own row on $machine');
  }
}
