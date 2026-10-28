import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/over_ssh.dart';
import '../support/world.dart';

/// Usage: a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine
Future<void> aTerminalRunsOnTheMachine(WidgetTester tester, String command) async {
  // What was run, and that it is a terminal somebody types into — never a value this program holds.
  expect(World.terminals, isNotEmpty, reason: 'no terminal was opened');
  if (command == 'porelo vault unlock' || command == 'ssh -t alice@vm porelo vault unlock') {
    // The unlock asks again after a refused passphrase: `porelo vault unlock` inside a small loop of sh.
    final run = World.terminals.last.command;
    final loop = run.last;
    expect(run.take(run.length - 1), command.startsWith('ssh ') ? ['ssh', '-t', 'alice@vm'] : ['sh', '-c']);
    expect(loop, allOf(contains('porelo vault unlock'), contains('for attempt in 1 2 3'), contains('-eq 70')));
  } else {
    expect(World.terminals.last.command.join(' '), asRunOverSsh(command));
  }
  expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
  // Where the typing goes is shown while it waits, whatever runs in it hides.
  expect(tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal'))).alwaysShowCursor, isTrue);
}
