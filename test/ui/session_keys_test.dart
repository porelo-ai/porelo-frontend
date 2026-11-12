import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';

/// A task's terminal in the window sends what a plain terminal sends to the same task's tmux, which Porelo sets up
/// as a plain terminal's: each key and report as xterm writes it, with TERM=xterm-256color. tmux runs on the alternate
/// screen and asks for its keys there, so each test first has the far end say what tmux says when it attaches.
void main() {
  late Desk before;
  setUp(() => before = desk);
  tearDown(() => desk = before);

  // What tmux writes on attaching to a task: the alternate screen, application cursor keys, the mouse in SGR form,
  // focus reports and modified keys.
  const attached = '\x1b[?1049h\x1b[?1h\x1b[?1000h\x1b[?1006h\x1b[?1004h\x1b[>4;1m';

  Future<({_Channel channel, Session session, FocusNode focus})> open(WidgetTester tester) async {
    desk = Desk.of('linux', const <String, String>{});
    final channel = _Channel();
    final session = Session(
      task: 'porelo-x-work',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('elsewhere')),
              Expanded(
                child: SessionView(session: session, focusNode: focus),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    channel.emit(attached);
    await tester.pump();
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    channel.sent.clear();
    return (channel: channel, session: session, focus: focus);
  }

  Future<List<String>> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    List<LogicalKeyboardKey> held = const [],
  }) async {
    final opened = await open(tester);
    for (final each in held) {
      await tester.sendKeyDownEvent(each);
    }
    await tester.sendKeyEvent(key);
    for (final each in held.reversed) {
      await tester.sendKeyUpEvent(each);
    }
    await tester.pump();
    await opened.session.leave();
    return opened.channel.sent;
  }

  testWidgets('Esc goes out at once, alone', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.escape), ['\x1b']);
  });

  testWidgets('Shift+Enter goes out as a modified Enter once tmux asked for modified keys', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.enter, held: [LogicalKeyboardKey.shiftLeft]), ['\x1b[27;2;13~']);
  });

  testWidgets('Ctrl+Left goes out as xterm writes it', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.arrowLeft, held: [LogicalKeyboardKey.controlLeft]), ['\x1b[1;5D']);
  });

  testWidgets('Alt+Up goes out as xterm writes it', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.arrowUp, held: [LogicalKeyboardKey.altLeft]), ['\x1b[1;3A']);
  });

  // Harm: on the alternate screen the terminal sent nothing for them, so tmux's copy mode could not be reached by
  // the keys a plain terminal scrolls back with.
  testWidgets('Shift+PageUp reaches tmux, which scrolls back in its copy mode', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.pageUp, held: [LogicalKeyboardKey.shiftLeft]), ['\x1b[5;2~']);
  });

  testWidgets('Shift+PageDown reaches tmux, which scrolls down and leaves its copy mode', (tester) async {
    expect(await press(tester, LogicalKeyboardKey.pageDown, held: [LogicalKeyboardKey.shiftLeft]), ['\x1b[6;2~']);
  });

  // Harm: tmux asks for focus reports and passes them on to the agent, and the terminal never sent one.
  testWidgets('the terminal reports losing and gaining focus once tmux asked for it', (tester) async {
    final opened = await open(tester);
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pump();
    opened.focus.requestFocus();
    await tester.pump();
    await opened.session.leave();
    expect(opened.channel.sent, ['\x1b[O', '\x1b[I']);
  });

  testWidgets('no focus report goes out where the far end did not ask for it', (tester) async {
    desk = Desk.of('linux', const <String, String>{});
    final channel = _Channel();
    final session = Session(
      task: 'porelo-x-work',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionView(session: session, focusNode: focus),
        ),
      ),
    );
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    focus.unfocus();
    await tester.pump();
    await session.leave();
    expect(channel.sent, isEmpty);
  });

  testWidgets('truecolor from the far end is drawn in its own colour', (tester) async {
    final opened = await open(tester);
    opened.channel.emit('\x1b[38;2;12;34;56mX');
    await tester.pump();
    await tester.pump();
    final line = opened.session.terminal.buffer.lines[opened.session.terminal.buffer.cursorY];
    final foreground = line.getForeground(opened.session.terminal.buffer.cursorX - 1);
    await opened.session.leave();
    expect(foreground & 0xffffff, 0x0c2238, reason: 'RGB 12, 34, 56');
  });
}

class _Channel implements SessionChannel {
  final List<String> sent = <String>[];
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  @override
  Stream<List<int>> get output => _output.stream;

  /// Has the far end write [text].
  void emit(String text) => _output.add(utf8.encode(text));

  @override
  void send(String input) => sent.add(input);

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    if (!_ended.isCompleted) _ended.complete(0);
  }
}
