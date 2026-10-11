import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/over_ssh.dart';
import '../support/world.dart';

/// Usage: a terminal runs {'ssh -t alice@vm sokar vault unlock'} on the machine
Future<void> aTerminalRunsOnTheMachine(WidgetTester tester, String command) async {
  // What was run, and that it is a terminal somebody types into — never a value this program holds.
  expect(World.terminals, isNotEmpty, reason: 'no terminal was opened');
  expect(World.terminals.last.command.join(' '), asRunOverSsh(command));
  expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
  // Where the typing goes is shown while it waits, whatever runs in it hides.
  expect(tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal'))).alwaysShowCursor, isTrue);
}
