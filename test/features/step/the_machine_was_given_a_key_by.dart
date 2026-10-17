import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was given a key by {'porelo vault put git.ssh.example'}
Future<void> theMachineWasGivenAKeyBy(WidgetTester tester, String command) async {
  // On its standard input and nowhere else: the command carries no part of the value.
  expect(World.setup.stored, isNotEmpty, reason: 'nothing was sent');
  expect(World.setup.stored.last.command.join(' '), command);
  expect(World.setup.stored.last.length, greaterThan(0));
}
