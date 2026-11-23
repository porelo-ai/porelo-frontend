import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/earlier_output.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';

import '../features/support/world.dart';
import '../support/session_recording.dart';

import 'package:porelo_frontend/src/ui/earlier_output_pane.dart';

/// A task's terminal showing its earlier output from the daemon on demand, read only above the live terminal.
///
/// The stand-in machine serves a recording and its positions: a page asked with a position it never gave is refused.
void main() {
  const task = 'porelo-billing-shell';
  // More than a session keeps, so the daemon's recording holds lines before what the window's terminal shows.
  final recorded = <String>[for (var i = 0; i < Session.scrollback + 2500; i++) 'output $i'];

  late FakeBackend backend;
  late FocusNode focus;
  late Session session;
  late FakeTerminal channel;
  late List<String> copied;

  setUp(() {
    copied = <String>[];
    final before = copyToClipboard;
    copyToClipboard = (text) async => copied.add(text);
    addTearDown(() => copyToClipboard = before);
  });

  setUp(() {
    backend = FakeBackend(<Task>[]);
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 1280,
    SessionRecording? recording,
    bool noRecording = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (!noRecording) backend.recordings[task] = recording ?? SessionRecording(recorded);
    focus = FocusNode();
    addTearDown(focus.dispose);
    session = Session(
      task: task,
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel = FakeTerminal(<String>[executable]),
    );
    addTearDown(session.leave);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionView(session: session, focusNode: focus, backend: backend),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> askForEarlier(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('terminal-earlier-open')));
    await tester.pump();
    await tester.pump();
  }

  String status(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('earlier-status'))).data!;

  /// Pulls the list down to its oldest line until it says how it ends.
  Future<void> scrollToTheTop(WidgetTester tester) async {
    for (
      var i = 0;
      i < 60 && !find.byKey(const Key('earlier-status')).evaluate().any((_) => !status(tester).startsWith('Loading'));
      i++
    ) {
      await tester.drag(find.byKey(const Key('earlier-list')), const Offset(0, 6000));
      await tester.pump();
      await tester.pump();
    }
  }

  // Harm: the live terminal's own buffer is rewritten under the person, or a line is lost or shown twice: the lines
  // the screen shows are the recording's newest, and only those are dropped, none older.
  testWidgets('earlier output opens above the terminal, drops the screen’s lines from the newest page and no older', (
    tester,
  ) async {
    await open(tester);
    session.terminal.write('what the live terminal shows\r\n');
    final textBefore = session.terminal.buffer.getText().trim();
    final rows = session.terminal.buffer.lines.length;
    await askForEarlier(tester);
    final newest = recorded.length - 1 - rows;

    expect(find.byKey(const Key('earlier-output')), findsOneWidget);
    expect(find.byKey(const Key('terminal')), findsOneWidget, reason: 'the live terminal stays below');
    expect(session.terminal.buffer.getText().trim(), textBefore, reason: 'nothing is written into the live terminal');
    expect(find.text('output $newest'), findsOneWidget, reason: 'the newest line the screen does not show');
    expect(find.text('output ${newest + 1}'), findsNothing, reason: 'a line the screen shows is not repeated');
    expect(find.byKey(const Key('earlier-overlap')), findsNothing, reason: 'the overlap was found, so no divider');
    await scrollToTheTop(tester);

    expect(status(tester), 'Nothing older is kept.');
    final shown = tester
        .widgetList<Text>(find.descendant(of: find.byKey(const Key('earlier-list')), matching: find.byType(Text)))
        .map((text) => text.data)
        .toList();
    expect(shown, contains('output 0'), reason: 'the session’s first line is reachable');
    expect(
      tester.widget<Text>(find.byKey(const Key('earlier-title'))).data,
      contains('${recorded.length - rows} lines'),
      reason: 'every line but the screen’s is held',
    );
    expect(tester.takeException(), isNull);
  });

  // Harm: lines dropped on a guess where nothing matches what the terminal shows, so the person sees them nowhere.
  testWidgets('no matching line drops nothing and shows the divider beside the terminal', (tester) async {
    backend.screens[task] = const Screen(lines: <String>['a line the recording never had'], live: true);
    await open(tester);
    await askForEarlier(tester);

    expect(find.text('output ${recorded.length - 1}'), findsOneWidget, reason: 'the newest recorded line is kept');
    expect(
      tester.widget<Text>(find.byKey(const Key('earlier-overlap'))).data,
      'The lines above this one and the terminal’s may overlap: no line here matched what the terminal shows.',
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('earlier-overlap'))).dy,
      greaterThan(tester.getBottomLeft(find.text('output ${recorded.length - 1}')).dy),
      reason: 'the divider stands at the newest end, beside the terminal',
    );
  });

  // Harm: a run that matches only part of what the terminal shows hides the divider, so the person reads the lines
  // above it as certainly not repeated.
  testWidgets('a match shorter than the screen is dropped and still shows the divider', (tester) async {
    final tail = recorded.sublist(recorded.length - 4);
    backend.screens[task] = Screen(lines: <String>['a line only the screen has', ...tail], live: true);
    await open(tester);
    await askForEarlier(tester);

    expect(find.text('output ${recorded.length - 5}'), findsOneWidget, reason: 'the four matching lines are dropped');
    expect(find.text('output ${recorded.length - 4}'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('earlier-overlap'))).data,
      contains('only 4 of the terminal’s lines matched'),
    );
  });

  // Harm: an `end` that is not a whole number reads as a recording that is not kept, so a reply this window cannot read
  // looks like a session with nothing older.
  testWidgets('an end that is no whole number is a failure said so, not "not kept"', (tester) async {
    backend.screens[task] = const Screen(lines: <String>[], live: true, endMalformed: true);
    await open(tester, noRecording: true);
    await askForEarlier(tester);
    expect(status(tester), contains('no whole number'));
    expect(find.byKey(const Key('earlier-retry')), findsOneWidget);
    expect(backend.screenBeforeSizes[task], isNull);
  });

  // Harm: a wheel turned up while the terminal is scrolled back, short of its oldest line, opens the earlier output over
  // the lines the person is reading.
  testWidgets('the wheel turned up away from the oldest line leaves the pane closed', (tester) async {
    await open(tester);
    for (var i = 0; i < 300; i++) {
      session.terminal.write('line $i\r\n');
    }
    await tester.pump();
    await tester.pump();
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(const Key('terminal')))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('earlier-output')), findsNothing);
  });

  /// Selects text in the pane with the mouse, from its first line drawn to its last.
  Future<void> selectInThePane(WidgetTester tester) async {
    final list = tester.getRect(find.byKey(const Key('earlier-list')));
    final gesture = await tester.startGesture(list.topLeft + const Offset(40, 10), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(list.topLeft + const Offset(200, 60));
    await gesture.up();
    await tester.pump();
  }

  // Harm: a selection in the pane cannot be copied by key, or Ctrl+C copies it and also interrupts the program in the
  // session.
  for (final (name, shift) in <(String, bool)>[('Ctrl+C', false), ('Ctrl+Shift+C', true)]) {
    testWidgets('$name copies what is selected in the pane and sends nothing to the session', (tester) async {
      await open(tester);
      await askForEarlier(tester);
      await selectInThePane(tester);
      final typed = channel.typed.length;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(copied, hasLength(1));
      expect(copied.single, contains('output '), reason: 'the pane’s lines reach the clipboard');
      expect(channel.typed.length, typed, reason: 'nothing reaches the session’s input');
    });
  }

  // Harm: Ctrl+C is swallowed where nothing is selected in the pane, so a program in the session cannot be interrupted.
  testWidgets('Ctrl+C with nothing selected in the pane still reaches the session', (tester) async {
    await open(tester);
    await askForEarlier(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied, isEmpty);
    expect(channel.typed, contains('\x03'));
  });

  // Harm: a Screen of more lines than the terminal shows drops lines a tmux history the window does not hold also has,
  // and the lost-lines bug comes back.
  testWidgets('Screen is asked for the terminal’s rows and never for its scrollback', (tester) async {
    await open(tester);
    final rows = session.terminal.buffer.lines.length;
    await askForEarlier(tester);
    expect(backend.screenLastAsked[task], <int>[rows]);
    expect(rows, lessThan(Session.scrollback));
  });

  // Harm: a page of more than 1000 lines is asked for, which the daemon refuses, or earlier output grows by one
  // unbounded request.
  testWidgets('earlier output is asked for in pages of at most 1000 lines', (tester) async {
    await open(tester);
    await askForEarlier(tester);
    await scrollToTheTop(tester);
    final sizes = backend.screenBeforeSizes[task]!;
    expect(sizes.length, greaterThan(1), reason: 'more than one page');
    expect(sizes.every((size) => size >= 1 && size <= 1000), isTrue, reason: '$sizes');
  });

  // Harm: a wheel turned past the oldest line goes nowhere, so the person never learns earlier output exists.
  testWidgets('the wheel turned up at the terminal’s oldest line opens the earlier output', (tester) async {
    await open(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(const Key('terminal')))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('earlier-output')), findsOneWidget);
  });

  // Harm: a session the daemon keeps no recording of is shown as one that starts at its last lines.
  testWidgets('no end in Screen says the earlier output is not kept, and no page is asked for', (tester) async {
    backend.screens[task] = const Screen(lines: <String>['only line'], live: true);
    await open(tester, noRecording: true);
    await askForEarlier(tester);
    expect(status(tester), 'This session’s earlier output is not kept.');
    expect(backend.screenBeforeSizes[task], isNull);
  });

  // Harm: a call the machine does not serve reads as the start of the session, or as nothing said, with no way to ask
  // again.
  testWidgets('a ScreenBefore answered with MethodNotImplemented is a failure that offers Try again', (tester) async {
    backend.screenBeforeRefusals[task] = const VarlinkException('org.varlink.service.MethodNotImplemented');
    await open(tester);
    await askForEarlier(tester);
    expect(status(tester), contains('The machine refused: MethodNotImplemented'));
    expect(find.byKey(const Key('earlier-retry')), findsOneWidget);
    expect(find.textContaining('Nothing older is kept'), findsNothing);
  });

  // Harm: a refusal reads as the start of the session, and the person cannot ask again.
  testWidgets('a refusal is said with what the daemon answered, and asking again reads the page', (tester) async {
    backend.screenBeforeRefusals[task] = const VarlinkException('org.fuin.porelo.Tasks1.InvalidParameter');
    await open(tester);
    final rows = session.terminal.buffer.lines.length;
    await askForEarlier(tester);
    expect(status(tester), contains('The machine refused: InvalidParameter'));
    expect(find.textContaining('starts'), findsNothing);
    expect(find.byKey(const Key('earlier-retry')), findsOneWidget);

    backend.screenBeforeRefusals.remove(task);
    await tester.tap(find.byKey(const Key('earlier-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('earlier-retry')), findsNothing);
    expect(
      find.text('output ${recorded.length - 1 - rows}'),
      findsOneWidget,
      reason: 'the newest line the screen does not show is shown after the retry',
    );
  });

  // Harm: the answer to a call that was out when the pane closed is applied anyway, and asks for page after page for a
  // pane nobody sees.
  testWidgets('closing the pane while its first call is out asks for nothing more and throws nothing', (tester) async {
    final held = Completer<void>();
    backend.screenHolds[task] = held;
    await open(tester);
    await askForEarlier(tester);
    expect(status(tester), startsWith('Loading'));

    await tester.tap(find.byKey(const Key('earlier-close')));
    await tester.pump();
    held.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('earlier-output')), findsNothing);
    expect(backend.screenBeforeSizes[task], isNull, reason: 'no page is asked for after it was closed');
    expect(tester.takeException(), isNull);
  });

  // Harm: a tap on an earlier line takes the keyboard from the terminal, so Escape and typed keys stop reaching the far
  // end of the terminal while the pane is open.
  testWidgets('a tap in the earlier output leaves the keyboard with the terminal', (tester) async {
    await open(tester);
    expect(focus.hasFocus, isTrue);
    await askForEarlier(tester);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('earlier-list'))));
    await tester.pump();
    expect(focus.hasFocus, isTrue, reason: 'right after the tap, not only after Close');
    await tester.tap(find.byKey(const Key('earlier-close')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  // Harm: a full-screen program on the alternate screen uses the wheel itself, and a wheel turned up over it opens the
  // earlier output of the main screen instead.
  testWidgets('the wheel turned up over the alternate screen does not open the earlier output', (tester) async {
    await open(tester);
    session.terminal.write('\x1b[?1049h');
    await tester.pump();
    expect(session.terminal.isUsingAltBuffer, isTrue);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(const Key('terminal')))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('earlier-output')), findsNothing);
  });

  // Harm: at a phone's width the sentence that says how the output ends is cut off or overflows.
  testWidgets('at 390 wide the ending is said whole', (tester) async {
    backend.screenBeforeRefusals[task] = const VarlinkException('org.fuin.porelo.Tasks1.InvalidParameter');
    await open(tester, width: 390);
    await tester.tap(find.byKey(const Key('terminal-earlier-open')));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(status(tester), contains('The machine refused: InvalidParameter'));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(const Key('earlier-status')), matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'the whole sentence shows');
    expect(
      paragraph.size.height,
      greaterThan(paragraph.text.style!.fontSize! * 1.5),
      reason: 'it wraps instead of being cut',
    );
    expect(tester.getRect(find.byKey(const Key('earlier-status'))).right, lessThanOrEqualTo(390));
  });

  // Harm: a recorded line with a direction override or control characters reads as text it is not.
  test('a recorded line is drawn without control characters or direction overrides', () {
    expect(shownLine('rm \u202Etxt.exe\u202C ok\x07\x1b'), 'rm txt.exe ok');
    expect(shownLine('a\tb'), 'a\tb', reason: 'a tab stays');
  });

  // Harm: one huge line held whole costs unbounded memory.
  test('a line is cut as it is stored', () {
    final huge = cutLine('x' * (mostLineCharacters + 10));
    expect(huge, startsWith('x' * mostLineCharacters));
    expect(huge, endsWith('(10 more characters not shown)'));
    expect(cutLine('short'), 'short');
  });
}
