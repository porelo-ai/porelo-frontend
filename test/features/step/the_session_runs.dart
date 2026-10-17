import 'package:flutter_test/flutter_test.dart';

import '../support/over_ssh.dart';
import '../support/world.dart';

/// Usage: the session runs {'porelo task attach porelo-billing-shell'}
Future<void> theSessionRuns(WidgetTester tester, String command) async {
  expect(World.terminals, isNotEmpty, reason: 'no session was opened');
  expect(World.terminals.last.command.join(' '), asRunOverSsh(command));
}
