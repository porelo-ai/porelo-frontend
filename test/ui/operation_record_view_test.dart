import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/ui/operations.dart';

/// A finished run read back from its record: it opens at its end and reads older lines on demand.
void main() {
  const total = Operation.windowLines + Operation.pageLines * 2 + 30;

  Future<Operation> reopened(WidgetTester tester, {int lines = total}) async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[
      <String, Object?>{
        'id': 'operation-1',
        'title': 'Build the environment',
        'machine': 'this machine',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'state': 'succeeded',
        'summary': 'Finished.',
        'seen': true,
      },
    ]);
    await store.appendOutput('operation-1', <String>[for (var line = 1; line <= lines; line++) 'line $line']);
    final operations = Operations(store: store, saveDelay: Duration.zero);
    await operations.load();
    addTearDown(operations.dispose);
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationOutputView(operation: operations.all.single, onBack: () {}, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return operations.all.single;
  }

  // Harm: a record read back opens at its first lines, so what just happened is not where the person looks.
  testWidgets('a record read back opens at its end', (tester) async {
    await reopened(tester);

    expect(find.text('line $total'), findsOneWidget);
    expect(find.text('line 1'), findsNothing);
  });

  // Harm: the lines before the first one held can never be reached, or reading them throws the reader's
  // place away, or the held lines grow without bound.
  testWidgets('scrolling up reads older lines from the record until its first line', (tester) async {
    final operation = await reopened(tester);

    for (var swipe = 0; swipe < 400 && operation.hasOlder; swipe++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 600), 30000);
      await tester.pumpAndSettle();
      expect(operation.output.length, lessThanOrEqualTo(Operation.windowLines));
    }
    for (var swipe = 0; swipe < 20; swipe++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 600), 30000);
      await tester.pumpAndSettle();
    }

    expect(operation.hasOlder, isFalse, reason: 'the start of the record was reached');
    expect(find.text('line 1'), findsOneWidget);
    expect(operation.output.first, 'line 1');
  });

  // Harm: a record with nothing older is shown with a promise of older lines, or its short end is hidden.
  testWidgets('a short record shows all of it and promises nothing older', (tester) async {
    final operation = await reopened(tester, lines: 3);

    expect(operation.hasOlder, isFalse);
    expect(find.text('line 1'), findsOneWidget);
    expect(find.text('line 3'), findsOneWidget);
    expect(find.byKey(const Key('older-lines')), findsNothing);
  });

  // Harm: a record that cannot be read is shown as one that printed nothing.
  testWidgets('a record that cannot be read says so and does not read as empty', (tester) async {
    final operation = await reopened(tester, lines: 3);
    operation
      ..output.clear()
      ..readProblem = 'Permission denied';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationOutputView(operation: operation, onBack: () {}, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-read-failed')), findsOneWidget);
    expect(find.text('It printed nothing at all.'), findsNothing);
  });

  Future<void> show(WidgetTester tester, Operation operation) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationOutputView(operation: operation, onBack: () {}, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Harm: lines are let go of while a read is still going, and the list builds from the old counts at the next
  // frame, which shows wrong lines or throws a range error.
  testWidgets('a frame drawn while a page is being read builds from the lines held now', (tester) async {
    const lines = 3200;
    final source = _Slow(<String>[for (var line = 1; line <= lines; line++) 'line $line']);
    final operation = Operation(id: 'operation-1', title: 'Build', startedAt: DateTime.now())
      ..state = OperationState.succeeded
      ..fromBefore = true;
    await operation.openRecord(source);
    await show(tester, operation);
    source.hold = true;

    Future<void> swipe(double by) async {
      await tester.fling(find.byType(CustomScrollView), Offset(0, by), 30000);
      // A frame while the read is out, then the read arrives.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      source.release();
      await tester.pumpAndSettle();
    }

    for (var round = 0; round < 8; round++) {
      await swipe(600);
    }
    expect(operation.hasOlder, isTrue);
    for (var round = 0; round < 16; round++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -600), 30000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      if (source.pending) {
        // The window already let go of lines for this page. Scrolling now builds lines that were not built yet.
        for (var drag = 0; drag < 6; drag++) {
          await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
          await tester.pump();
        }
      }
      source.release();
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(operation.output.length, lessThanOrEqualTo(Operation.windowLines));
  });

  // Harm: the second opening of a record starts where the first one left the window, with the newest lines let go,
  // so what happened last is not what is shown.
  testWidgets('a record opened again shows its end, whatever the first opening scrolled through', (tester) async {
    final operation = await reopened(tester);
    for (var swipe = 0; swipe < 400 && operation.hasOlder; swipe++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 600), 30000);
      await tester.pumpAndSettle();
    }
    expect(operation.output.last, isNot('line $total'), reason: 'the newest lines were let go');
    await tester.pumpWidget(const SizedBox());

    await show(tester, operation);

    expect(find.text('line $total'), findsOneWidget);
  });

  // Harm: reading a page or letting go of lines moves what the reader is looking at, so the place is lost.
  testWidgets('a line on screen stays where it is across every load and every shift of the window', (tester) async {
    final operation = await reopened(tester);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);

    /// Moves by [by] and says how far a line that was on screen before and after moved.
    Future<double> step(double by) async {
      final texts = find.byType(SelectableText);
      String? probe;
      var before = 0.0;
      for (var i = 0; i < texts.evaluate().length; i++) {
        final top = tester.getTopLeft(texts.at(i)).dy;
        // A line that is still on screen after the move: lower down when the move is upward.
        if (by > 0 ? top > 150 && top < 350 : top > 400 && top < 600) {
          probe = tester.widget<SelectableText>(texts.at(i)).data;
          before = top;
          break;
        }
      }
      expect(probe, isNotNull, reason: 'a line is on screen to be followed');
      await tester.drag(find.byType(CustomScrollView), Offset(0, by));
      await tester.pumpAndSettle();
      return tester.getTopLeft(find.text(probe!)).dy - before;
    }

    final up = await step(250);
    var steps = 0;
    var loaded = false;
    while ((operation.hasOlder || scrollable.position.pixels - scrollable.position.minScrollExtent > 300) &&
        steps++ < 400) {
      final held = operation.output.length;
      final moved = await step(250);
      expect(moved, closeTo(up, 0.5), reason: 'step $steps (held $held lines) moved the line it showed');
      loaded = loaded || operation.output.length != held;
    }
    expect(loaded, isTrue, reason: 'pages were read on the way');
    final down = await step(-250);
    steps = 0;
    while ((operation.hasNewer || scrollable.position.maxScrollExtent - scrollable.position.pixels > 300) &&
        steps++ < 400) {
      final moved = await step(-250);
      expect(moved, closeTo(down, 0.5), reason: 'step $steps downward moved the line it showed');
    }
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('line $total'), findsOneWidget);
  });

  // Harm: a run whose lines are gone from disk reads as one that printed nothing.
  testWidgets('a run whose lines are missing says so and not that it printed nothing', (tester) async {
    final operation = Operation(id: 'operation-1', title: 'Build', startedAt: DateTime.now())
      ..state = OperationState.succeeded
      ..fromBefore = true
      ..linesPrintedBefore = 12
      ..recordOf = () async => null;
    await show(tester, operation);

    expect(find.byKey(const Key('lines-missing')), findsOneWidget);
    expect(find.text('It printed nothing at all.'), findsNothing);
  });

  // Harm: lines that could not be written leave a record that reads as whole.
  testWidgets('a record that lost lines says how many', (tester) async {
    final operation = Operation(id: 'operation-1', title: 'Build', startedAt: DateTime.now())
      ..state = OperationState.succeeded
      ..fromBefore = true
      ..linesPrintedBefore = 0
      ..linesLost = 3;
    await show(tester, operation);

    expect(find.byKey(const Key('lines-lost')), findsOneWidget);
  });

  // Harm: Try again after the record failed to open does nothing, because no record is held to read more of.
  testWidgets('Try again opens the record that failed to open', (tester) async {
    var tries = 0;
    final operation = Operation(id: 'operation-1', title: 'Build', startedAt: DateTime.now())
      ..state = OperationState.succeeded
      ..fromBefore = true
      ..linesPrintedBefore = 2
      ..recordOf = () async {
        if (tries++ == 0) throw const FileSystemException('Permission denied');
        return MemoryOutput(<String>['first', 'second']);
      };
    await show(tester, operation);

    await tester.tap(find.byKey(const Key('record-read-again')));
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.byKey(const Key('record-read-failed')), findsNothing);
  });
}

/// A record whose reads wait until they are let go, as a slow disk's do.
class _Slow extends MemoryOutput {
  _Slow(super.lines);

  bool hold = false;

  bool get pending => _gate != null;
  Completer<void>? _gate;

  Future<void> _wait() async {
    if (!hold) return;
    final gate = _gate = Completer<void>();
    await gate.future;
  }

  void release() {
    final gate = _gate;
    _gate = null;
    gate?.complete();
  }

  @override
  Future<OutputPage> before(int position, int count) async {
    await _wait();
    return super.before(position, count);
  }

  @override
  Future<OutputPage> after(int position, int count) async {
    await _wait();
    return super.after(position, count);
  }
}
