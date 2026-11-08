import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/running_view.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';
import 'package:porelo_frontend/src/ui/terminal_look.dart';
import 'package:xterm/xterm.dart';

import '../features/support/world.dart';

void main() {
  List<Task> many() => <Task>[
    for (var each = 10; each < 40; each++) World.aTask('porelo-a-rather-long-name-of-work-$each', 'checkout'),
  ];

  Future<void> toRunning(WidgetTester tester) async {
    await World.startBackend(many());
    await World.startApp(tester);
    await tester.tap(find.byKey(const Key('work-view-running')));
    await World.settle(tester);
  }

  // Harm: tabs past the window's edge can be neither seen nor reached.
  testWidgets('many tabs scroll sideways, and the chosen one comes into view', (tester) async {
    await toRunning(tester);
    expect(tester.takeException(), isNull);
    final scroller = tester.widget<SingleChildScrollView>(find.byKey(const Key('running-tabs')));
    expect(scroller.scrollDirection, Axis.horizontal);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);

    expect(tester.widget<Text>(find.byKey(const Key('running-name'))).data, 'porelo-a-rather-long-name-of-work-39');
    final tab = find.text('a-rather-long-name-of-work-39');
    expect(tester.getTopRight(tab).dx, lessThanOrEqualTo(tester.view.physicalSize.width));
  });

  // Harm: a list and tabs that overflow on a window as narrow as a phone's.
  testWidgets('the list and the tabs fit a narrow window', (tester) async {
    await toRunning(tester);
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    await World.settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('work-view-list')));
    await World.settle(tester);
    expect(tester.takeException(), isNull);
  });

  // Harm: a tablet's bar squeezes the work into a tall column and leaves no usable terminal after changing views.
  testWidgets('Running keeps its terminal room across widths and List round trips', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await tester.tap(find.byKey(const Key('work-view-running')));
    await World.settle(tester);
    final tab = find.byKey(ValueKey<String>('running-tab ${World.machines.current.name}/porelo-billing-shell'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await World.settle(tester);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [1280.0, 390.0, 700.0]) {
      tester.view.physicalSize = Size(width, 800);
      await World.settle(tester);
      expect(tester.takeException(), isNull, reason: 'Running must fit at $width wide');
      final running = find.byType(RunningView);
      final terminal = find.byKey(const Key('terminal'));
      expect(terminal.hitTestable(), findsOneWidget);
      final runningRect = tester.getRect(running);
      final terminalSize = tester.getSize(terminal);

      for (var visit = 0; visit < 2; visit++) {
        await tester.tap(find.byKey(const Key('work-view-list')));
        await World.settle(tester);
        await tester.ensureVisible(find.byKey(const Key('work-view-running')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('work-view-running')));
        await World.settle(tester);
        expect(tester.takeException(), isNull, reason: 'return $visit at $width wide');
        expect(tester.getRect(running), runningRect, reason: 'List must not keep room from Running');
        expect(terminal.hitTestable(), findsOneWidget);
        expect(tester.getSize(terminal), terminalSize, reason: 'the terminal keeps its room after List');
        expect(World.sessions.current?.task, 'porelo-billing-shell');
      }
    }
  });

  group('a console follows the window', () {
    Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: child),
      ),
    );

    for (final (name, brightness) in <(String, Brightness)>[('light', Brightness.light), ('dark', Brightness.dark)]) {
      // Harm: a terminal pale on white, where an agent's and tmux's own colours do not read.
      testWidgets('a session stays dark in a $name window', (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final session = Session(
          task: 'porelo-x-work',
          machine: const Machine(name: 'here', socketPath: ''),
          open: (executable, arguments, {int columns = 80, int rows = 24}) => FakeTerminal(<String>[executable]),
        );
        addTearDown(session.leave);
        final theme = ThemeData(brightness: brightness);
        await pump(tester, theme, SessionView(session: session, focusNode: focus));
        await tester.pump();
        expect(tester.widget<TerminalView>(find.byKey(const Key('terminal'))).theme, TerminalLook.darkConsole);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
