import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine ran {'porelo vault put git.ssh.example --from-file /home/me/.ssh/id_ed25519'} with nothing on its standard input
Future<void> theMachineRanWithNothingOnItsStandardInput(WidgetTester tester, String command) async {
  expect(World.setup.stored, isNotEmpty, reason: 'nothing was run');
  expect(World.setup.stored.last.command.join(' '), command);
  expect(World.setup.stored.last.length, 0, reason: 'the machine reads its own disk; nothing is sent');
}
