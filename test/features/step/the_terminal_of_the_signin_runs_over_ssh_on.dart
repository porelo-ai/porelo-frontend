import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal of the sign-in runs over ssh on {'alice@vm'}
///
/// What the machine named is run on that machine, in its login shell, and never on this computer.
Future<void> theTerminalOfTheSigninRunsOverSshOn(WidgetTester tester, String host) async {
  expect(World.terminals, isNotEmpty, reason: 'no terminal of a sign-in is open');
  final command = World.terminals.last.command;
  expect(command.first, endsWith('ssh'), reason: 'run here, not on the machine: $command');
  expect(command, contains(host));
  expect(command.indexOf(host), lessThan(command.length - 1));
  expect(command.last, contains('podman attach porelo-login-an-agent'));
}
