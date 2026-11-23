import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/logs.dart';
import 'package:porelo_frontend/src/ui/log_view.dart';

import '../features/support/world.dart';

/// A task's log scrolled back past what its tail sent, against a stand-in that counts positions in lines.
///
/// The log is `earlier 1` ... `earlier N` before the first line its tail sends, then what the test prints.
void main() {
  late FakeBackend backend;
  late Logs logs;
  late LogTail tail;
  var formattedTail = false;

  // What the test's log writes next: into the tail it opened, formatted or not.
  void feed(List<String> written) =>
      formattedTail ? backend.formattedTails['work']!.add(written) : backend.tailing.add(written);

  Future<void> open(
    WidgetTester tester, {
    int earlier = 0,
    List<String> printed = const <String>[],
    double width = 1280,
    void Function(FakeBackend backend)? configure,
    bool formatted = false,
  }) async {
    formattedTail = formatted;
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = FakeBackend(<Task>[])..earlierLines = <String>[for (var at = 1; at <= earlier; at++) 'earlier $at'];
    configure?.call(backend);
    logs = Logs();
    addTearDown(logs.dispose);
    tail = logs.open(backend, 'work', 'agent.log', formatted: formatted);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: logs,
            builder: (context, _) => LogView(tail: tail, logs: logs, onClose: () {}),
          ),
        ),
      ),
    );
    feed(printed);
    await World.settle(tester);
  }

  List<String> lines(int count, [String name = 'now']) => <String>[for (var at = 1; at <= count; at++) '$name $at'];

  ScrollPosition position(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  /// Scrolls to the top, as a person does, and lets the answer arrive.
  Future<void> toTheTop(WidgetTester tester) async {
    final top = position(tester);
    top.jumpTo(top.minScrollExtent);
    await World.settle(tester);
  }

  bool shows(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

  String drawn(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((shown) => shown.data ?? shown.textSpan?.toPlainText() ?? '')
      .join('\n');

  // Harm: a log's earlier lines can never be read once it has opened on its last lines, or its start is not said.
  testWidgets('scrolling to the top reads the lines before the first, page by page, until the log starts', (
    tester,
  ) async {
    await open(tester, earlier: 2500, printed: lines(200));
    expect(backend.logBeforeAsked, isEmpty, reason: 'opening at the end asks for nothing');

    await toTheTop(tester);
    expect(backend.logBeforeAsked.single, (before: backend.positionOf(2500), lines: 1000));
    expect(tail.lines, hasLength(1200));
    expect(shows('log-start'), isFalse);

    await toTheTop(tester);
    await toTheTop(tester);
    expect(backend.logBeforeAsked.map((each) => each.before), <int>[
      backend.positionOf(2500),
      backend.positionOf(1500),
      backend.positionOf(500),
    ]);
    expect(tail.lines, hasLength(2700));
    expect(shows('log-start'), isTrue);
    expect(tail.lines.first, 'earlier 1');

    await toTheTop(tester);
    expect(backend.logBeforeAsked, hasLength(3), reason: 'nothing is asked for once the start is reached');
  });

  // Harm: a bounded first Tail reply is mistaken for the whole log and hides its earlier lines.
  testWidgets('a first tail reply shorter than last still offers paging before its byte position', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200));
    expect(backend.tailsAsked.single.last, Logs.firstLines);
    expect(tail.lines.length, lessThan(Logs.firstLines));
    expect(tail.wantsOlder, isTrue);
    expect(shows('log-start'), isFalse);

    await toTheTop(tester);

    expect(backend.logBeforeAsked.single, (before: backend.positionOf(2500), lines: 1000));
    expect(backend.logBeforeNames.single, backend.logOf);
    expect(tail.lines.first, 'earlier 1501');
  });

  // Harm: a new run's name is paired with an old position or old lines, mixing two runs or refusing scroll-back.
  for (final earlier in <int>[2500, 3500]) {
    testWidgets('a new tail name replaces the old run with $earlier earlier lines', (tester) async {
      await open(tester, earlier: 2500, printed: lines(200));
      final before = tail.start!;
      final oldName = backend.logOf;
      backend.replaceTheLog(<String>[for (var at = 1; at <= earlier; at++) 'earlier $at']);
      final newest = lines(200, 'new run');
      feed(newest);
      await World.settle(tester);

      final newestPosition = backend.positionOf(earlier);
      expect(tail.start, newestPosition);
      if (earlier == 2500) {
        expect(tail.start, before, reason: 'the same offset can belong to another log');
      } else {
        expect(tail.start, isNot(before), reason: 'the new name must retain its own position');
      }
      expect(tail.lines, newest, reason: 'no line of the previous run stays');
      await toTheTop(tester);

      expect(backend.logBeforeAsked.single.before, newestPosition);
      expect(backend.logBeforeNames.single, backend.logOf);
      expect(backend.logBeforeNames.single, isNot(oldName));
      expect(shows('log-older-failed'), isFalse);
    });
  }

  // Harm: a page or refusal arriving for the old run mixes its lines into, or restarts, the new run.
  for (final refused in <bool>[false, true]) {
    testWidgets('a pending old page with refusal $refused cannot change the new run', (tester) async {
      await open(tester, earlier: 2500, printed: lines(200));
      backend.logBeforeHeld = Completer<void>();
      final pending = logs.readOlder(tail);
      await tester.pump();
      expect(tail.older, OlderLines.loading);
      backend.replaceTheLog(<String>[for (var at = 1; at <= 2500; at++) 'earlier $at']);
      final newest = lines(200, 'new run');
      feed(newest);
      await World.settle(tester);
      if (refused) {
        backend.logBeforeRefusal = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchLog');
      }
      backend.logBeforeHeld!.complete();
      await pending;
      await World.settle(tester);

      expect(tail.lines, newest);
      expect(backend.tailsAsked, hasLength(1), reason: 'the old answer cannot start another Tail');
      expect(tail.older, OlderLines.idle);
      expect(tail.problem, isNull);
    });
  }

  // Harm: lines put in front move the lines being read, so a person who scrolled up loses their place.
  testWidgets('what is read stays where it was when earlier lines arrive above it', (tester) async {
    await open(tester, earlier: 100, printed: lines(200));
    backend.logBeforeHeld = Completer<void>();
    final top = position(tester);
    top.jumpTo(top.minScrollExtent);
    await World.settle(tester);
    final first = find.byWidgetPredicate((each) => each is SelectableText && each.textSpan?.toPlainText() == 'now 1');
    final before = tester.getTopLeft(first);
    expect(tail.lines, hasLength(200), reason: 'the answer has not come yet');

    backend.logBeforeHeld!.complete();
    await World.settle(tester);

    expect(tail.lines, hasLength(300));
    expect(tester.getTopLeft(first), before);
  });

  // Harm: a log whose lines fit the window has no top to scroll to, so its earlier lines are never offered.
  testWidgets('lines too few to scroll are not stranded without their earlier lines', (tester) async {
    await open(tester, earlier: 30, printed: lines(3));

    expect(backend.logBeforeAsked.single, (before: backend.positionOf(30), lines: 1000));
    expect(shows('log-start'), isTrue);
    expect(tail.lines, hasLength(33));
  });

  // Harm: a daemon that does not serve the call is shown as the log's start, or as a machine to leave alone, with
  // no way to ask again.
  testWidgets('a call the daemon does not serve is said as a failure with Try again, never the log\'s start', (
    tester,
  ) async {
    await open(tester, earlier: 2500, printed: lines(200));
    backend.logBeforeRefusal = const VarlinkException('org.varlink.service.MethodNotImplemented');

    await toTheTop(tester);

    expect(find.textContaining('Earlier lines could not be read'), findsOneWidget);
    expect(find.byKey(const Key('log-older-retry')), findsOneWidget);
    expect(shows('log-start'), isFalse);
    expect(tail.lines, hasLength(200));

    backend.logBeforeRefusal = null;
    await tester.tap(find.byKey(const Key('log-older-retry')));
    await World.settle(tester);

    expect(tail.lines, hasLength(1200), reason: 'asked again, and answered');
  });

  // Harm: a refusal is shown as the log's start, or leaves no way to ask again.
  testWidgets('a refusal is said, is not the start of the log, and can be asked again', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200));
    backend.logBeforeRefusal = const VarlinkException('org.fuin.porelo.Tasks1.Refused');

    await toTheTop(tester);

    expect(find.textContaining('Earlier lines could not be read'), findsOneWidget);
    expect(shows('log-start'), isFalse);
    expect(tail.lines, hasLength(200));

    backend.logBeforeRefusal = null;
    await tester.tap(find.byKey(const Key('log-older-retry')));
    await World.settle(tester);

    expect(tail.lines, hasLength(1200));
    expect(find.textContaining('Earlier lines could not be read'), findsNothing);
  });

  // Harm: at 390 wide the words or the retry of a refusal are cut off or overflow the line.
  testWidgets('a refusal and its retry are whole at 390 wide', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200), width: 390);
    backend.logBeforeRefusal = const VarlinkException('org.fuin.porelo.Tasks1.Refused');

    await toTheTop(tester);

    expect(tester.takeException(), isNull);
    final retry = tester.getRect(find.byKey(const Key('log-older-retry')));
    expect(retry.right, lessThanOrEqualTo(390));
    expect(tester.getRect(find.byKey(const Key('log-older-failed'))).right, lessThanOrEqualTo(390));
  });

  // Harm: after a new run replaced the log, its old lines stay mixed with the new run's, or the view stays failed.
  testWidgets('a log replaced by a new run is read again from its end', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200));
    backend.replaceTheLog(<String>[for (var at = 1; at <= 3000; at++) 'new earlier $at']);

    await toTheTop(tester);
    feed(<String>['new run line']);
    await World.settle(tester);

    expect(backend.tailsAsked.where((each) => !each.formatted), hasLength(2));
    expect(tail.lines, <String>[
      for (var at = 2001; at <= 3000; at++) 'new earlier $at',
      'new run line',
    ], reason: 'the old run is gone');
    expect(
      backend.logBeforeNames.first,
      isNot(backend.logOf),
      reason: 'the stale name is refused even within the new log',
    );
    expect(backend.logBeforeNames.last, backend.logOf);
    expect(backend.logBeforeAsked.last, (
      before: backend.positionOf(3000),
      lines: 1000,
    ), reason: 'a short view reads the new log back');
    expect(shows('log-replaced'), isTrue);
    expect(shows('log-older-failed'), isFalse);
  });

  // Harm: reading back through a large log keeps all of it in memory, as the walk that closed the interface did.
  testWidgets('the window holds a bounded number of lines and offers the newest again', (tester) async {
    await open(tester, earlier: 7000, printed: lines(1000));
    for (var page = 0; page < 5; page++) {
      await toTheTop(tester);
    }

    expect(tail.lines.length, lessThanOrEqualTo(LogTail.kept));
    expect(shows('log-newer-dropped'), isTrue);
    expect(tail.lines.first, 'earlier 2001');

    feed(<String>['arrived while reading back']);
    await World.settle(tester);
    expect(tail.lines, isNot(contains('arrived while reading back')), reason: 'a gap is never closed by guessing');

    await tester.tap(find.byKey(const Key('log-newest')));
    feed(<String>['again from the end']);
    await World.settle(tester);

    expect(backend.tailsAsked.where((each) => !each.formatted), hasLength(2));
    expect(tail.lines.last, 'again from the end');
    expect(tail.lines, isNot(contains('arrived while reading back')));
    expect(tail.lines, isNot(contains('earlier 2001')), reason: 'what was read back is let go');
    expect(shows('log-newer-dropped'), isFalse);
  });

  // Harm: lines a following log let go cannot be read again, or come back at the wrong place with a gap or twice.
  testWidgets('lines let go at the start of a followed log are read again in their place', (tester) async {
    await open(tester, earlier: 0, printed: lines(1000, 'line'));
    var next = 1001;
    while (next < 5800) {
      feed(<String>[for (var at = next; at < next + 100; at++) 'line $at']);
      next += 100;
    }
    await World.settle(tester);

    expect(tail.dropped, 0, reason: 'cut where a position is known, so none is lost for good');
    expect(tail.lines.length, lessThanOrEqualTo(LogTail.kept));
    final firstHeld = int.parse(tail.lines.first.substring(5));
    expect(firstHeld, greaterThan(1));

    await toTheTop(tester);

    final numbers = <int>[for (final line in tail.lines) int.parse(line.substring(5))];
    expect(numbers.first, firstHeld > 1000 ? firstHeld - 1000 : 1);
    for (var at = 1; at < numbers.length; at++) {
      expect(numbers[at], numbers[at - 1] + 1, reason: 'no gap and no line twice');
    }
  });

  // Harm: an answer that lands after the log was closed puts lines into, or notifies, what nobody holds.
  testWidgets('an answer after the log was closed changes nothing', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200));
    backend.logBeforeHeld = Completer<void>();

    await toTheTop(tester);
    expect(tail.older, OlderLines.loading);
    logs.close(tail);
    backend.logBeforeHeld!.complete();
    await World.settle(tester);

    expect(tail.lines, hasLength(200));
    expect(tester.takeException(), isNull);
  });

  List<int> numbersOf(List<String> held) => <int>[for (final line in held) int.parse(line.substring(5))];

  void expectNoGapAndNoRepeat(List<String> held) {
    final numbers = numbersOf(held);
    for (var at = 1; at < numbers.length; at++) {
      expect(numbers[at], numbers[at - 1] + 1, reason: 'no gap and no line twice');
    }
  }

  // Harm: a page that lands after lines arrived and cut the window's oldest end is put before a window that now
  // begins later, leaving lines missing between them without a word.
  testWidgets('a page read before the window was cut is let go and asked for again from where it begins', (
    tester,
  ) async {
    await open(tester);
    backend.earlierLines = <String>[for (var at = 1; at <= 3000; at++) 'line $at'];
    var next = 3001;
    void print(int count) {
      feed(<String>[for (var at = next; at < next + count; at++) 'line $at']);
      next += count;
    }

    print(1000);
    while (next < 8001) {
      print(100);
    }
    await World.settle(tester);
    expect(tail.lines, hasLength(LogTail.kept));
    final held = tail.start!;

    backend.logBeforeHeld = Completer<void>();
    unawaited(logs.readOlder(tail));
    await tester.pump();
    expect(backend.logBeforeAsked.last.before, held);
    print(300);
    await World.settle(tester);
    expect(tail.start, isNot(held), reason: 'the arrival cut the oldest end');
    final cutFirst = numbersOf(tail.lines).first;

    backend.logBeforeHeld!.complete();
    await World.settle(tester);

    expect(backend.logBeforeAsked.length, greaterThanOrEqualTo(2));
    expect(numbersOf(tail.lines).first, lessThan(cutFirst), reason: 'the page asked for again landed');
    expectNoGapAndNoRepeat(tail.lines);
  });

  // Harm: a page that formatting emptied, though it moved back, is shown as a failure and stops the way back.
  testWidgets('an empty page that moved back is taken, and the next is asked for', (tester) async {
    await open(
      tester,
      earlier: 3000,
      printed: lines(200),
      formatted: true,
      configure: (backend) => backend.hiddenLines = <int>{for (var at = 2000; at < 3000; at++) at},
    );

    await toTheTop(tester);

    expect(shows('log-older-failed'), isFalse);
    expect(backend.logBeforeAsked.map((each) => each.before), <int>[
      backend.positionOf(3000),
      backend.positionOf(2000),
    ]);
    expect(tail.lines, hasLength(200 + 1000));
  });

  Future<void> fillPastTheWindow(WidgetTester tester) async {
    await open(tester, printed: lines(1000, 'line'));
    logs.follow(tail, following: false);
    var next = 1001;
    while (next <= 5000) {
      feed(<String>[for (var at = next; at < next + 100; at++) 'line $at']);
      next += 100;
    }
    await World.settle(tester);
    expect(tail.lines, hasLength(LogTail.kept));
    feed(<String>[for (var at = next; at < next + 100; at++) 'line $at']);
    await World.settle(tester);
  }

  // Harm: while a person reads back, lines arriving cut the oldest end of the window and move what they read.
  testWidgets('lines past the window are not taken in while reading back, and the oldest stay', (tester) async {
    await fillPastTheWindow(tester);

    expect(tail.lines.first, 'line 1');
    expect(tail.lines, hasLength(LogTail.kept));
    expect(tail.newerDropped, isTrue);
    expect(shows('log-newer-dropped'), isTrue);
    expectNoGapAndNoRepeat(tail.lines);
  });

  // Harm: the switch says the log is followed while its reading was stopped, so nothing new ever arrives.
  testWidgets('turning Follow on where the newest were let go reads the log from its end', (tester) async {
    await fillPastTheWindow(tester);

    await tester.tap(find.byKey(const Key('follow')));
    feed(<String>['after the end']);
    await World.settle(tester);

    expect(backend.tailsAsked.where((each) => !each.formatted), hasLength(2));
    expect(tail.newerDropped, isFalse);
    expect(tail.following, isTrue);
    expect(tail.lines.last, 'after the end');
  });

  // Harm: a Tail reply the window cannot read is shown as a log with nothing before it, or in the raw words of
  // an exception.
  testWidgets('a malformed tail is said as a failure of the machine\'s answer', (tester) async {
    await open(tester, earlier: 10, printed: lines(5));

    backend.tailing.addError(const FormatException('Tail answered without the offset of its first line'));
    await World.settle(tester);

    expect(find.textContaining('The machine answered something this window cannot read'), findsOneWidget);
  });

  // Harm: the interface claims a new run replaced the log when the machine only refused a position, and drops
  // what was read to read again.
  testWidgets(
    'a refused position is said as the machine\'s refusal, keeps what was read and reads from the end on asking',
    (tester) async {
      await open(
        tester,
        earlier: 2500,
        printed: lines(200),
        configure: (backend) =>
            backend.replacedAnswer = const VarlinkException('org.fuin.porelo.Tasks1.InvalidParameter'),
      );
      backend.replaceTheLog(<String>['new earlier 1']);

      await toTheTop(tester);

      expect(find.textContaining('The machine refused the position'), findsOneWidget);
      expect(shows('log-replaced'), isFalse, reason: 'no new run is claimed');
      expect(tail.lines, hasLength(200), reason: 'what was read stays');
      expect(backend.tailsAsked.where((each) => !each.formatted), hasLength(1));

      await tester.tap(find.byKey(const Key('log-older-retry')));
      feed(<String>['from the end']);
      await World.settle(tester);

      expect(backend.tailsAsked.where((each) => !each.formatted), hasLength(2));
      expect(tail.lines, contains('from the end'));
      expect(tail.lines, isNot(contains('now 1')));
    },
  );

  // Harm: a log the machine no longer has loses what was read before anything else was read, and the words
  // are not the daemon's.
  testWidgets('a log the machine no longer has keeps what was read and says so', (tester) async {
    await open(tester, earlier: 2500, printed: lines(200));
    backend.replaceTheLog(<String>['new earlier 1']);
    backend.theLogsItHas = <String>{};

    await toTheTop(tester);

    expect(find.textContaining('This log no longer exists on the machine'), findsOneWidget);
    expect(tail.lines, hasLength(200), reason: 'nothing is dropped before a read succeeds');
    expect(shows('log-replaced'), isFalse);
    expect(drawn(tester), contains('now 1'));
  });

  // Harm: scrolling by the view itself to the end of a slightly scrollable log is taken for the person
  // reading back, and Follow turns itself off.
  testWidgets('a log a little taller than the view stays followed', (tester) async {
    await open(
      tester,
      earlier: 3000,
      printed: lines(60),
      configure: (backend) => backend.logBeforeHeld = Completer<void>(),
    );
    final extent = position(tester).maxScrollExtent - position(tester).minScrollExtent;
    expect(extent, inInclusiveRange(1, 400), reason: 'about one and a half views tall');

    expect(tail.following, isTrue);
    expect(find.byKey(const Key('follow')), findsOneWidget);
  });

  // Harm: a window that is full while the log is written hard asks for a page again for ever, each answer
  // let go because the window moved on.
  testWidgets('a page asked for again once is not asked for for ever while the log moves', (tester) async {
    await open(tester);
    backend.earlierLines = <String>[for (var at = 1; at <= 3000; at++) 'line $at'];
    var next = 3001;
    void print(int count) {
      feed(<String>[for (var at = next; at < next + count; at++) 'line $at']);
      next += count;
    }

    print(1000);
    while (next < 8001) {
      print(100);
    }
    await World.settle(tester);
    expect(tail.lines, hasLength(LogTail.kept));
    backend.whileLogBefore = () async {
      print(800);
      for (var turn = 0; turn < 8; turn++) {
        await Future<void>.value();
      }
    };

    await logs.readOlder(tail);
    await World.settle(tester);

    expect(backend.logBeforeAsked, hasLength(2), reason: 'once more, then said');
    expect(tail.older, OlderLines.failed);
    expect(tail.olderWords, contains('moved on'));
  });

  // Harm: a window cut to no known start leaves the view saying it reads earlier lines for ever.
  testWidgets('a page let go because the window lost its start does not leave the view reading', (tester) async {
    await open(tester, earlier: 3000, printed: lines(200, 'line'));
    backend.logBeforeHeld = Completer<void>();
    unawaited(logs.readOlder(tail));
    await World.settle(tester);
    expect(shows('log-older-loading'), isTrue);

    feed(lines(6000, 'big'));
    await World.settle(tester);
    expect(tail.start, isNull);
    backend.logBeforeHeld!.complete();
    await World.settle(tester);

    expect(tail.older, OlderLines.idle);
    expect(shows('log-older-loading'), isFalse);
  });

  // Harm: a page that came back short leaves the view at the top with nothing to scroll, so the way back stalls.
  testWidgets('a short page that leaves the view at the top asks for the next', (tester) async {
    await open(
      tester,
      earlier: 3000,
      printed: lines(200),
      formatted: true,
      configure: (backend) => backend.hiddenLines = <int>{
        for (var at = 0; at < 3000; at++)
          if (at % 100 != 0) at,
      },
    );

    await toTheTop(tester);

    expect(backend.logBeforeAsked.length, greaterThan(1), reason: 'asked on without another scroll');
    expect(tail.lines.length, greaterThan(210));
  });

  // Harm: pages that formatting empties chain without end, asked for with nobody scrolling.
  testWidgets('after three empty pages nothing is asked until the person scrolls again', (tester) async {
    await open(
      tester,
      earlier: 5000,
      printed: lines(200),
      formatted: true,
      configure: (backend) => backend.hiddenLines = <int>{for (var at = 2000; at < 5000; at++) at},
    );

    await toTheTop(tester);
    expect(backend.logBeforeAsked, hasLength(3));
    expect(shows('log-older-failed'), isFalse);
    await World.settle(tester);
    expect(backend.logBeforeAsked, hasLength(3), reason: 'it waits');

    final top = position(tester);
    top.jumpTo(top.minScrollExtent + 50);
    top.jumpTo(top.minScrollExtent);
    await World.settle(tester);

    expect(backend.logBeforeAsked.length, greaterThan(3));
    expect(tail.lines.length, greaterThan(200));
  });
}
