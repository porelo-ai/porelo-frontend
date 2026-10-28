import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';
import 'package:porelo_frontend/src/ui/tile_console.dart';
import 'package:xterm/xterm.dart';

import '../features/support/world.dart';

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

  Future<(Session, _Channel)> open(WidgetTester tester, {DateTime? startedAt}) async {
    final channel = _Channel();
    final session = Session(
      task: 'porelo-sluice-dry-sluice',
      machine: const Machine(name: 'laptop', socketPath: ''),
      open: (executable, arguments, {int columns = 80, int rows = 24}) => channel,
      startedAt: startedAt,
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionView(session: session, focusNode: FocusNode(), onLeave: () {}),
        ),
      ),
    );
    await tester.pump();
    addTearDown(session.leave);
    return (session, channel);
  }

  Future<void> prints(WidgetTester tester, _Channel channel, String words) async {
    channel.prints(words);
    await tester.pump();
  }

  bool offered(String address) => find.byKey(ValueKey<String>('terminal-link $address')).evaluate().isNotEmpty;

  testWidgets('a link to the gate as the task sees it gets no browser button; one to the forge does', (tester) async {
    final (_, channel) = await open(tester);
    const inside = 'http://host.containers.internal/sluice.git';
    const forge = 'https://github.com/example/sluice/pull/1';
    await prints(tester, channel, '\x1b]8;;$inside\x1b\\$inside\x1b]8;;\x1b\\\r\n');
    await prints(tester, channel, '\x1b]8;;$forge\x1b\\$forge\x1b]8;;\x1b\\\r\n');

    expect(offered(inside), isFalse, reason: 'the laptop’s browser cannot reach the container’s gate');
    expect(find.textContaining('only reachable inside the task'), findsOneWidget);
    expect(offered(forge), isTrue, reason: 'an address this computer reaches keeps its button');
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

  testWidgets('a tile says when its task was started, and nothing where that is unknown', (tester) async {
    Future<void> tile({DateTime? startedAt}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TileConsole(
            backend: FakeBackend(const <Task>[]),
            task: 'porelo-sluice-dry-sluice',
            onEnlarge: () {},
            startedAt: startedAt,
          ),
        ),
      ),
    );

    await tile(startedAt: DateTime(2026, 10, 28, 20, 10));
    expect(find.text('started 20:10'), findsOneWidget);

    await tile();
    expect(find.textContaining('started'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  group('the mouse, while the program asked for mouse reports', () {
    const mouseReports = '\x1b[?1000h\x1b[?1006h';

    Offset cell(WidgetTester tester, int column) =>
        tester.getTopLeft(find.byKey(const Key('terminal'))) + Offset(12 + column * 8.0, 12);

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

  testWidgets('what the program copies reaches the clipboard, and a read of it gets no answer', (tester) async {
    final (_, channel) = await open(tester);
    await prints(tester, channel, '\x1b]52;c;${base64.encode(utf8.encode('git log --oneline'))}\x07');
    expect(copied, <String>['git log --oneline']);

    await prints(tester, channel, '\x1b]52;c;?\x07');
    expect(copied, hasLength(1), reason: 'a read copies nothing');
    expect(channel.sent.where((each) => each.contains(']52')), isEmpty, reason: 'nor is it answered');
  });
}

class _Channel implements SessionChannel {
  final List<String> sent = <String>[];
  final StreamController<List<int>> _output = StreamController<List<int>>.broadcast();
  final Completer<int> _ended = Completer<int>();

  void prints(String words) => _output.add(utf8.encode(words));

  @override
  Stream<List<int>> get output => _output.stream;

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
