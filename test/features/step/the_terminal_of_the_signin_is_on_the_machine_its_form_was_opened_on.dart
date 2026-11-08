import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal of the sign-in is on the machine its form was opened on
Future<void> theTerminalOfTheSigninIsOnTheMachineItsFormWasOpenedOn(WidgetTester tester) async {
  expect(World.sessions.beside, isNotEmpty, reason: 'no terminal of a login task is open');
  expect(World.sessions.beside.last.machine, World.machines.all.first);
}
