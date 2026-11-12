import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machine_setup.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';
import 'package:porelo_frontend/src/ui/new_machine.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';
import 'package:porelo_frontend/src/ui/unlock_terminal.dart';

import '../features/support/world.dart';
import '../support/terminal_drag.dart';

void main() {
  for (final (kind, asks) in <(String, bool)>[
    for (final kind in <String>['session', 'unlock', 'vault']) ...<(String, bool)>[(kind, false), (kind, true)],
  ]) {
    // A sign-in code or secret pasted with the Linux shortcut goes nowhere or reaches the far end as a stray key; a
    // task's own write to the clipboard held where nothing asks about it, or copied without a word.
    testWidgets(
      asks
          ? '$kind terminal asks before a write to the clipboard and takes a drag in it as a copy'
          : '$kind terminal sends the clipboard once for each paste shortcut',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        // The test's own time, so what it pumps is what the window waits.
        final clockBefore = sessionClock;
        sessionClock = () =>
            () => Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch);
        addTearDown(() => sessionClock = clockBefore);
        try {
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          const clipboard = 'clipboard-example';
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return <String, String>{'text': clipboard};
            return null;
          });
          addTearDown(
            () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final far = FakeTerminal(<String>[]);
          const machine = Machine(name: 'test machine', socketPath: '/unused');
          final focus = FocusNode();
          addTearDown(focus.dispose);
          late final session = Session(
            task: 'work',
            machine: machine,
            open: (executable, arguments, {int columns = 80, int rows = 24}) => far,
          );
          if (kind == 'session') addTearDown(() => session.dispose());
          final run =
              SetupRun(
                  name: 'test machine',
                  workUser: 'alice',
                  setup: MachineSetup(home: '/unused'),
                )
                ..step = SetupStep.vault
                ..ready = machine;
          addTearDown(run.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: switch (kind) {
                  'session' => SessionView(session: session, focusNode: focus),
                  'vault' => NewMachineSteps(
                    run: run,
                    openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) => far,
                  ),
                  _ => Builder(
                    builder: (context) => TextButton(
                      onPressed: () => unlockInATerminal(
                        context,
                        machine: machine,
                        command: <String>['porelo', 'vault', 'unlock'],
                        open: (executable, arguments, {int columns = 80, int rows = 24}) => far,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                },
              ),
            ),
          );
          if (kind == 'unlock') await tester.tap(find.text('Open'));
          if (kind == 'vault') await tester.tap(find.byKey(const Key('open-vault-terminal')));
          await World.settle(tester);
          final key = kind == 'session' ? 'terminal' : '$kind-terminal';
          if (asks) {
            await tester.pump(const Duration(seconds: 5));
            final copied = <String>[];
            final before = copyToClipboard;
            copyToClipboard = (text) async => copied.add(text);
            addTearDown(() => copyToClipboard = before);
            far.prints('\x1b]52;c;${base64.encode(utf8.encode('by itself'))}\x07');
            await World.settle(tester);
            expect(copied, isEmpty, reason: 'a write the task makes by itself is held');
            expect(find.byKey(const Key('terminal-copy-ask')), findsOneWidget, reason: 'and asked about');
            far.prints('\x1b[2J\x1b[Hafter a drag');
            await World.settle(tester);
            await dragAcrossTheTopLine(tester, find.byKey(Key(key)), 'after a drag'.length);
            far.prints('\x1b]52;c;${base64.encode(utf8.encode('after a drag'))}\x07');
            await World.settle(tester);
            expect(copied, <String>['after a drag'], reason: 'a drag across its text in this terminal is a copy');
            await tester.pumpWidget(const SizedBox.shrink());
            await World.settle(tester);
            return;
          }
          await tester.tap(find.byKey(Key(key)));
          await World.settle(tester);
          final received = <List<String>>[];
          for (final modifiers in <List<LogicalKeyboardKey>>[
            <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
            <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
            <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
          ]) {
            far.typed.clear();
            for (final modifier in modifiers) {
              await tester.sendKeyDownEvent(modifier);
            }
            await tester.sendKeyEvent(
              modifiers.length == 1 && modifiers.single == LogicalKeyboardKey.shiftLeft
                  ? LogicalKeyboardKey.insert
                  : LogicalKeyboardKey.keyV,
            );
            for (final modifier in modifiers.reversed) {
              await tester.sendKeyUpEvent(modifier);
            }
            await World.settle(tester);
            received.add(List<String>.of(far.typed));
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await World.settle(tester);
          expect(received, <List<String>>[
            <String>[clipboard],
            <String>[clipboard],
            <String>[clipboard],
          ], reason: 'each shortcut must deliver the clipboard exactly once, without stray keys');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
