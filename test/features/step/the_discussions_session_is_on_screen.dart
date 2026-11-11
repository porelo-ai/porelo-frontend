import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the discussion's session is on screen
Future<void> theDiscussionsSessionIsOnScreen(WidgetTester tester) async {
  final project = World.backend.discussed.single.project;
  final open = World.sessions.current?.task;
  expect(open, isNotNull, reason: 'no session was opened for the discussion');
  expect(World.machines.fleet.tasks.where((each) => each.name == open && each.project == project), hasLength(1));
  expect(find.byKey(const Key('terminal')), findsOneWidget);
}
