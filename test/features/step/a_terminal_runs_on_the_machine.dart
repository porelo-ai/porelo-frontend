import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/vault_unlock.dart';
import 'package:xterm/xterm.dart';

import '../support/over_ssh.dart';
import '../support/world.dart';

/// Usage: a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine
Future<void> aTerminalRunsOnTheMachine(WidgetTester tester, String command) async {
  // What was run, and that it is a terminal somebody types into — never a value this program holds.
  expect(World.terminals, isNotEmpty, reason: 'no terminal was opened');
  if (command == 'porelo vault unlock' || command == 'ssh -t alice@vm porelo vault unlock') {
    final machine = command.startsWith('ssh ')
        ? const Machine(
            name: 'remote',
            socketPath: '/tmp/remote.sock',
            host: 'alice@vm',
            remoteSocket: '/run/porelo.sock',
          )
        : Machine.local(environment: const {});
    expect(World.terminals.last.command, unlockCommandFor(machine));
  } else {
    expect(World.terminals.last.command.join(' '), asRunOverSsh(command));
  }
  expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
  // Where the typing goes is shown while it waits, whatever runs in it hides.
  expect(tester.widget<TerminalView>(find.byKey(const Key('unlock-terminal'))).alwaysShowCursor, isTrue);
}
