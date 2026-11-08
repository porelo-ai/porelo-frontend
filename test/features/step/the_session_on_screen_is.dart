import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session on screen is {'porelo-billing-audit'}
Future<void> theSessionOnScreenIs(WidgetTester tester, String task) async {
  expect(World.sessions.current?.task, task);
  expect(find.byKey(const Key('terminal')), findsOneWidget);
  // By what a person calls it: the container's name is only in its details.
  final shown = World.machines.fleet.tasks.where((each) => each.name == task).firstOrNull?.shown ?? task;
  expect(find.textContaining(shown), findsWidgets);
}
