import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_terminal.dart';
import 'package:xterm/xterm.dart';

/// What the person does in a session's terminal on screen, as the clipboard's gate hears it.
///
/// The harm: a task's write to the clipboard taken as the person's copy when the person dragged across nothing, or
/// long after they turned away from the terminal.
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

  Future<(Session, _Channel, FocusNode)> show(WidgetTester tester) async {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
    );
    addTearDown(session.leave);
    final elsewhere = FocusNode();
    addTearDown(elsewhere.dispose);
    final controller = TerminalController();
    addTearDown(controller.dispose);
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The task asks for the mouse, as tmux does, so drags go to it.
    channel.prints('\x1b[?1002h\x1b[2J\x1b[Hcopy me');
    await tester.pump();
    return (session, channel, elsewhere);
  }

  /// The middle of cell ([x], [y]) on the screen.
  Offset cell(WidgetTester tester, int x, int y) {
    final render = tester.state<TerminalViewState>(find.byKey(viewKey)).renderTerminal;
    final size = render.cellSize;
    return render.localToGlobal(render.getOffset(CellOffset(x, y)) + Offset(size.width / 2, size.height / 2));
  }

  Future<void> drag(WidgetTester tester, int fromX, int toX, {int buttons = kPrimaryButton}) async {
    final gesture = await tester.startGesture(cell(tester, fromX, 0), kind: PointerDeviceKind.mouse, buttons: buttons);
    await gesture.moveTo(cell(tester, toX, 0));
    await gesture.up();
    // Past the wait for a second tap, which the terminal's own gestures keep.
    await tester.pump(kDoubleTapTimeout * 2);
  }

  Future<void> writes(WidgetTester tester, _Channel channel, String text) async {
    channel.prints('\x1b]52;c;${base64.encode(utf8.encode(text))}\x07');
    await tester.pump();
  }

  testWidgets('a drag across text lets a write of that text through', (tester) async {
    final (session, channel, _) = await show(tester);
    await drag(tester, 0, 6);
    await writes(tester, channel, 'copy me');
    expect(copied, <String>['copy me']);
    expect(session.held, isNull);
  });

  testWidgets('a press let go on the cell it was pressed on is no drag', (tester) async {
    final (session, channel, _) = await show(tester);
    await drag(tester, 3, 3);
    // The letter on that cell, which a copy of it would be.
    await writes(tester, channel, 'y');
    expect(copied, isEmpty);
    expect(session.held?.text, 'y');
  });

  testWidgets('a drag with another button is no copy', (tester) async {
    final (session, channel, _) = await show(tester);
    await drag(tester, 0, 6, buttons: kSecondaryButton);
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  testWidgets('a drag while another pointer is down is no copy', (tester) async {
    final (session, channel, _) = await show(tester);
    final other = await tester.startGesture(cell(tester, 10, 2), kind: PointerDeviceKind.touch);
    await drag(tester, 0, 6);
    await other.up();
    await tester.pump(kDoubleTapTimeout * 2);
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });

  testWidgets('the keyboard leaving the terminal ends what a drag lets through', (tester) async {
    final (session, channel, elsewhere) = await show(tester);
    await drag(tester, 0, 6);
    elsewhere.requestFocus();
    await tester.pump();
    await writes(tester, channel, 'copy me');
    expect(copied, isEmpty);
    expect(session.held?.text, 'copy me');
  });
}

class _Channel implements SessionChannel {
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    if (!_ended.isCompleted) _ended.complete(0);
  }
}
