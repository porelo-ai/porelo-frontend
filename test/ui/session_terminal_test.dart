import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_terminal.dart';
import 'package:xterm/xterm.dart';

/// What the person does in a session's terminal on screen, as the clipboard's gate hears it.
///
/// The harm: a task's write to the clipboard taken as the person's copy when the person dragged across nothing, across
/// other text than the screen showed, or after they turned away from the terminal.
void main() {
  late CopyToClipboard before;
  late List<String> copied;
  setUp(() {
    before = copyToClipboard;
    copied = <String>[];
    copyToClipboard = (text) async => copied.add(text);
  });
  tearDown(() => copyToClipboard = before);

  const viewKey = Key('the-terminal');

  Future<(Session, _Channel, FocusNode, ScrollController)> show(WidgetTester tester) async {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
      // The test's own time, so what it pumps is what the gate waits.
      clock: () => Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch),
    );
    addTearDown(session.leave);
    final elsewhere = FocusNode();
    addTearDown(elsewhere.dispose);
    final controller = TerminalController();
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: elsewhere, child: const SizedBox(width: 10, height: 10)),
              SizedBox(
                width: 800,
                height: 400,
                child: SessionTerminal(
                  session: session,
                  viewKey: viewKey,
                  theme: TerminalThemes.defaultTheme,
                  controller: controller,
                  textStyle: const TerminalStyle(),
                  padding: EdgeInsets.zero,
                  scrollController: scroll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The task has not asked for the mouse, so a drag selects here.
    channel.prints('\x1b[2J\x1b[Hcopy me');
    await tester.pump();
    return (session, channel, elsewhere, scroll);
  }

  /// The middle of the cell in column [x] and row [row] of the screen's last page.
  Offset cell(WidgetTester tester, int x, int row) {
    final render = tester.state<TerminalViewState>(find.byKey(viewKey)).renderTerminal;
    final terminal = tester.widget<TerminalView>(find.byKey(viewKey)).terminal;
    final size = render.cellSize;
    final top = terminal.buffer.height - terminal.viewHeight;
    return render.localToGlobal(render.getOffset(CellOffset(x, top + row)) + Offset(size.width / 2, size.height / 2));
  }

  // Past the wait for a second tap, which the terminal's own gestures keep.
  Future<void> settle(WidgetTester tester) => tester.pump(kDoubleTapTimeout * 2);

  Future<void> drag(WidgetTester tester, int fromX, int toX, {int buttons = kPrimaryButton}) async {
    final gesture = await tester.startGesture(cell(tester, fromX, 0), kind: PointerDeviceKind.mouse, buttons: buttons);
    await gesture.moveTo(cell(tester, toX, 0));
    await gesture.up();
    await settle(tester);
  }

  Future<void> writes(WidgetTester tester, _Channel channel, String text) async {
    channel.prints('\x1b]52;c;${base64.encode(utf8.encode(text))}\x07');
    await tester.pump();
  }

  Future<void> prints(WidgetTester tester, _Channel channel, String words) async {
    channel.prints(words);
    await tester.pump();
  }

  /// Fills the screen with `row 0` down to its last row, the cursor left at the end of the last.
  Future<int> fill(WidgetTester tester, _Channel channel, Session session) async {
    final rows = session.terminal.viewHeight;
    await prints(tester, channel, '\x1b[2J\x1b[H${List<String>.generate(rows, (row) => 'row $row').join('\r\n')}');
    return rows;
  }

  testWidgets('a drag across text lets a write of that text through', (tester) async {
    final (session, channel, _, _) = await show(tester);
    await drag(tester, 0, 6);
    await writes(tester, channel, 'copy me');
    expect(copied, <String>['copy me']);
    expect(session.held, isNull);
  });

  testWidgets('a press let go on the cell it was pressed on is no drag', (tester) async {
    final (session, channel, _, _) = await show(tester);
    await drag(tester, 3, 3);
    // The letter on that cell, which a copy of it would be.
    await writes(tester, channel, 'y');
    expect(copied, isEmpty);
    expect(session.held?.text, 'y');
  });

  testWidgets('a drag with another button is no copy', (tester) async {
    final (session, channel, _, _) = await show(tester);
    await drag(tester, 0, 6, buttons: kSecondaryButton);
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  testWidgets('a drag while another pointer is down is no copy', (tester) async {
    final (session, channel, _, _) = await show(tester);
    final other = await tester.startGesture(cell(tester, 10, 2), kind: PointerDeviceKind.touch);
    await drag(tester, 0, 6);
    await other.up();
    await settle(tester);
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  testWidgets('the keyboard leaving the terminal ends what a drag lets through', (tester) async {
    final (session, channel, elsewhere, _) = await show(tester);
    await drag(tester, 0, 6);
    elsewhere.requestFocus();
    await tester.pump();
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  testWidgets('two seconds of the test clock after a drag still copy, a moment more asks', (tester) async {
    final (session, channel, _, _) = await show(tester);
    await drag(tester, 0, 6);
    await tester.pump(const Duration(seconds: 2) - kDoubleTapTimeout * 2);
    await writes(tester, channel, 'copy me');
    expect(copied, <String>['copy me']);

    await drag(tester, 0, 6);
    await tester.pump(const Duration(seconds: 2, milliseconds: 1) - kDoubleTapTimeout * 2);
    await writes(tester, channel, 'copy me');
    expect(copied, <String>['copy me']);
    expect(session.held?.text, 'copy me');
  });

  group('while the task hears the mouse', () {
    // Harm: the drag went to the task, which copies whatever it likes as the person's.
    testWidgets('a drag lets nothing through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await prints(tester, channel, '\x1b[?1002h');
      await drag(tester, 0, 6);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('a press it heard is no drag, even when it lets go of the mouse before the release', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await prints(tester, channel, '\x1b[?1000h');
      final gesture = await tester.startGesture(cell(tester, 0, 0), kind: PointerDeviceKind.mouse);
      await prints(tester, channel, '\x1b[?1000l');
      await gesture.moveTo(cell(tester, 6, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });
  });

  group('a gesture under moving text', () {
    // Harm: output scrolling under a click turns it into a drag across lines the person never touched.
    testWidgets('a press let go where it was pressed while output scrolls is no drag', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await fill(tester, channel, session);
      final at = cell(tester, 0, 0);
      final gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await prints(tester, channel, '\r\nmore');
      await gesture.up();
      await settle(tester);
      expect(cell(tester, 0, 0), at, reason: 'the screen follows the output');
      // The text from the cell pressed to the one under the pointer now, a line further down the buffer.
      await writes(tester, channel, 'row 0\nr');
      expect(copied, isEmpty);
      expect(session.held?.text, 'row 0\nr');
    });

    testWidgets('a press let go where it was pressed while the view scrolls is no drag', (tester) async {
      final (session, channel, _, scroll) = await show(tester);
      final rows = await fill(tester, channel, session);
      await prints(tester, channel, '\r\n' * rows);
      final at = tester.getCenter(find.byKey(viewKey));
      final gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      final render = tester.state<TerminalViewState>(find.byKey(viewKey)).renderTerminal;
      final from = render.getCellOffset(render.globalToLocal(at));
      scroll.jumpTo(scroll.offset - render.cellSize.height * 3);
      await tester.pump();
      final to = render.getCellOffset(render.globalToLocal(at));
      expect(to, isNot(from), reason: 'another cell lies under the pointer');
      await gesture.up();
      await settle(tester);
      for (final end in <CellOffset>[from, CellOffset(from.x + 1, from.y)]) {
        await writes(tester, channel, session.terminal.buffer.getText(BufferRangeLine(to, end)));
      }
      expect(copied, isEmpty);
    });

    testWidgets('a drag while output scrolls the lines under it lets nothing through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await fill(tester, channel, session);
      final gesture = await tester.startGesture(cell(tester, 0, 0), kind: PointerDeviceKind.mouse);
      await prints(tester, channel, '\r\nmore');
      await gesture.moveTo(cell(tester, 4, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'row 0\nrow 1');
      expect(copied, isEmpty);
      expect(session.held?.text, 'row 0\nrow 1');
    });

    testWidgets('a drag across a line the task wrote over meanwhile lets nothing through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      final gesture = await tester.startGesture(cell(tester, 0, 0), kind: PointerDeviceKind.mouse);
      await prints(tester, channel, '\x1b[Hrm -rf');
      await gesture.moveTo(cell(tester, 6, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'rm -rf');
      expect(copied, isEmpty);
      expect(session.held?.text, 'rm -rf');
    });

    testWidgets('a drag while output changes only other lines still counts', (tester) async {
      final (_, channel, _, _) = await show(tester);
      final gesture = await tester.startGesture(cell(tester, 0, 0), kind: PointerDeviceKind.mouse);
      await prints(tester, channel, '\x1b[5;1Hstatus\x1b[1;8H');
      await gesture.moveTo(cell(tester, 6, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, <String>['copy me']);
    });
  });

  group('during a drag', () {
    testWidgets('another button pressed ends it', (tester) async {
      final (session, channel, _, _) = await show(tester);
      const pointer = 7;
      final gesture = await tester.startGesture(cell(tester, 0, 0), pointer: pointer, kind: PointerDeviceKind.mouse);
      await gesture.moveTo(cell(tester, 3, 0));
      tester.binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          kind: PointerDeviceKind.mouse,
          position: cell(tester, 4, 0),
          buttons: kPrimaryButton | kSecondaryButton,
        ),
      );
      await gesture.moveTo(cell(tester, 6, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('the keyboard leaving ends it', (tester) async {
      final (session, channel, elsewhere, _) = await show(tester);
      final gesture = await tester.startGesture(cell(tester, 0, 0), kind: PointerDeviceKind.mouse);
      await gesture.moveTo(cell(tester, 3, 0));
      elsewhere.requestFocus();
      await tester.pump();
      await gesture.moveTo(cell(tester, 6, 0));
      await gesture.up();
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });
  });

  group('after a drag', () {
    // Harm: a copy the person made with a key, or text they typed, taken as the drag's.
    testWidgets('a key ends what it lets through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await drag(tester, 0, 6);
      // A key that sends nothing to the far end.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('a key an input method takes while it composes ends what it lets through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await drag(tester, 0, 6);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  か',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('a press ends what it lets through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await drag(tester, 0, 6);
      await tester.tapAt(cell(tester, 2, 3), kind: PointerDeviceKind.mouse);
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('a press canceled ends what it lets through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await drag(tester, 0, 6);
      final gesture = await tester.startGesture(cell(tester, 2, 3), kind: PointerDeviceKind.mouse);
      await gesture.cancel();
      await settle(tester);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held?.text, 'copy me');
    });

    testWidgets('the session ending ends what it lets through', (tester) async {
      final (session, channel, _, _) = await show(tester);
      await drag(tester, 0, 6);
      channel.ends();
      await tester.pump();
      expect(session.state, SessionState.over);
      await writes(tester, channel, 'copy me');
      expect(copied, isEmpty);
      expect(session.held, isNull);
    });
  });
}

class _Channel implements SessionChannel {
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  void ends() {
    if (!_ended.isCompleted) _ended.complete(0);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async => ends();
}
