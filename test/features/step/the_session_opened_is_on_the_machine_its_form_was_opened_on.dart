import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session opened is on the machine its form was opened on
Future<void> theSessionOpenedIsOnTheMachineItsFormWasOpenedOn(WidgetTester tester) async {
  final opened = World.machines.all.first;
  expect(World.sessions.current, isNotNull, reason: 'the work brought up by hand opens its session');
  expect(World.sessions.current!.machine, opened, reason: 'the session must be on the work the start brought up');
}
