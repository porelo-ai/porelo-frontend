import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';
import 'package:porelo_frontend/src/ui/new_machine.dart';

import '../features/support/world.dart';

/// A machine whose work user's client answers who is signed in, and records what runs as that user.
class _Machine extends MachineSetup {
  _Machine() : super(home: '/unused');

  final commands = <String>[];

  @override
  Future<ProcessResult> asUser(String alias, String command) async {
    commands.add(command);
    if (command.contains('-p status')) return ProcessResult(0, 0, 'Logged in as:\tme@example.org\n', '');
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  // Harm: a drive asked for where none is wanted, or Tresorit's password typed into a field of this program.
  testWidgets('the drive step offers only its install, signs in in a terminal, and then syncs one tresor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final machine = _Machine();
    const reached = Machine(name: 'test machine', socketPath: '/unused');
    final run = SetupRun(name: 'test machine', workUser: 'alice', setup: machine)
      ..step = SetupStep.drive
      ..ready = reached;
    addTearDown(run.dispose);
    final terminals = <FakeTerminal>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewMachineSteps(
              run: run,
              openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
                final terminal = FakeTerminal([executable, ...arguments]);
                terminals.add(terminal);
                return terminal;
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('drive-explained')), findsOneWidget);
    expect(find.byKey(const Key('drive-install')), findsOneWidget);
    expect(find.byKey(const Key('drive-email')), findsNothing, reason: 'nothing asked before it is chosen');
    expect(find.byType(TextField), findsNothing);
    expect(run.canGoOn, isTrue, reason: 'Next leaves it out');

    // As if the install had passed its check.
    run
      ..driveInstalled = true
      ..changed();
    await World.settle(tester);
    expect(find.byType(TextField), findsOneWidget, reason: 'the e-mail alone; the password is Tresorit\'s to ask');
    Finder open() => find.byKey(const Key('open-drive-terminal'));
    await tester.enterText(find.byKey(const Key('drive-email')), "me'@example.org");
    await tester.pump();
    expect(tester.widget<OutlinedButton>(open()).onPressed, isNull, reason: 'no address a shell would split');
    await tester.enterText(find.byKey(const Key('drive-email')), 'me@example.org');
    await tester.pump();
    await tester.tap(open());
    await World.settle(tester);
    expect(terminals.single.command.last, contains('login --email me@example.org --password-on-stdin'));
    expect(terminals.single.command, contains('-t'), reason: 'a terminal of its own, as alice');

    terminals.single.endsWith(0);
    await World.settle(tester);
    expect(
      machine.commands.last,
      contains('-p status'),
      reason: 'who is signed in is asked, never read from the terminal',
    );
    expect(find.byKey(const Key('drive-signed-in')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('drive-tresor')), 'my files');
    await tester.pump();
    await tester.tap(find.byKey(const Key('drive-sync')));
    await World.settle(tester);
    expect(machine.commands.last, contains("sync --start 'my files'"));
    expect(run.driveSynced, 'my files');
  });
}
