import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';

/// On Windows the terminal reads every key from the keyboard's own events, letters included: there,
/// the text-input path the terminal widget uses elsewhere delivered Enter, Backspace and the page
/// keys and no letter at all (the operator's first Windows test).
void main() {
  late Desk before;
  setUp(() => before = desk);
  tearDown(() => desk = before);

  Future<List<String>> typeIn(WidgetTester tester, {required String operatingSystem}) async {
    desk = Desk.of(operatingSystem, const <String, String>{});
    final channel = _Channel();
    final session = Session(
      task: 'porelo-x-work',
      machine: const Machine(name: 'laptop', socketPath: '', kind: 'wsl', distribution: 'Ubuntu'),
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
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await session.leave();
    return channel.sent;
  }

  testWidgets('on Windows a letter and a digit reach the far end, as Enter does', (tester) async {
    expect((await typeIn(tester, operatingSystem: 'windows')).join(), 'a1\r');
  });

  Future<List<String>> wheel(WidgetTester tester, {required String operatingSystem, String before = ''}) async {
    desk = Desk.of(operatingSystem, const <String, String>{});
    final channel = _Channel();
    final session = Session(
      task: 'porelo-x-work',
      machine: const Machine(name: 'laptop', socketPath: '', kind: 'wsl', distribution: 'Ubuntu'),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionView(session: session, focusNode: FocusNode()),
        ),
      ),
    );
    await tester.pump();
    // What tmux writes on attaching: its own screen, and the mouse asked for in SGR form.
    if (before.isNotEmpty) {
      channel.emit(before);
      await tester.pump();
      await tester.pump();
    }
    final terminal = tester.getCenter(find.byKey(const Key('terminal')));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(terminal));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.pump();
    await session.leave();
    return channel.sent;
  }

  // Through a Windows pseudoconsole the terminal never learns that tmux asked for the mouse, so the
  // wheel is reported to tmux as tmux reads it on Linux: SGR wheel up (64) and down (65).
  testWidgets('on Windows the wheel goes to tmux as a wheel report, up and down', (tester) async {
    expect(await wheel(tester, operatingSystem: 'windows'), <String>['\x1b[<64;1;1M', '\x1b[<65;1;1M']);
  });

  testWidgets('on Linux the terminal itself answers the wheel, as before', (tester) async {
    expect(await wheel(tester, operatingSystem: 'linux'), isEmpty);
  });

  // Harm: on Linux tmux asks for the mouse, and the terminal reported the wheel as Shift+wheel (68 and 69), which
  // tmux binds to nothing: the wheel did not scroll a task's terminal at all.
  testWidgets('on Linux the wheel reaches tmux as a plain wheel report, up and down', (tester) async {
    final sent = await wheel(tester, operatingSystem: 'linux', before: '\x1b[?1049h\x1b[?1000h\x1b[?1002h\x1b[?1006h');
    expect(sent, isNotEmpty);
    expect(sent.where((each) => each.startsWith('\x1b[<64;')), isNotEmpty, reason: 'up, as $sent');
    expect(sent.where((each) => each.startsWith('\x1b[<65;')), isNotEmpty, reason: 'down, as $sent');
    expect(sent.where((each) => !each.startsWith('\x1b[<64;') && !each.startsWith('\x1b[<65;')), isEmpty);
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
