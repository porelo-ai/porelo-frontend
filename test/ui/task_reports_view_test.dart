import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/task_reports_view.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';

/// What a task reported back to its starter, on its row of Work: that new ones exist, and, opened, the reports.
void main() {
  const work = 'porelo-checkout-shell';

  Finder onTheRow(Finder what) => find.descendant(of: tileFor(work), matching: what);

  /// The work with [work] having made [reports], told to the window by its row.
  Future<void> reported(WidgetTester tester, List<TaskReport> reports) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await toThePlace(tester, 'work');
    World.backend.reportsOf[work] = reports;
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(
      Task.from({...wire(listed), 'reports': reports.isEmpty ? 0 : reports.last.seq, 'run': 'run-1'}),
    );
    await World.settle(tester);
  }

  /// Opens [work]'s row, which reads its reports.
  Future<void> open(WidgetTester tester) async {
    final fold = onTheRow(find.byKey(const ValueKey<String>('tile-fold $work')));
    if (onTheRow(find.byKey(const Key('tile-details'))).evaluate().isEmpty) {
      await tester.ensureVisible(fold);
      await tester.tap(fold);
      await World.settle(tester);
    }
  }

  TaskReport report(int seq, String text, {String kind = 'note'}) => TaskReport(seq: seq, kind: kind, text: text);

  // Harm: a task reports back and nothing on its row says so, or a row says so before anything was reported.
  testWidgets('a folded row says how many reports are new, and reads none of them yet', (tester) async {
    await reported(tester, [report(1, 'one'), report(2, 'two')]);

    expect(onTheRow(find.text('2 new reports')), findsOneWidget);
    expect(World.backend.reportsAsked, isEmpty, reason: 'read only when the row is opened');
  });

  // Harm: a person never learns what the task reported, or reads it as something other than what it wrote.
  testWidgets('opening a row reads its reports, shows each kind and text, and clears the count', (tester) async {
    await reported(tester, [report(1, 'Cache the mirror.\nA second build fetches nothing.', kind: 'idea')]);

    await open(tester);

    expect(World.backend.reportsAsked, [(work, null)]);
    expect(onTheRow(find.byKey(const ValueKey<String>('tile-report-kind 1'))), findsOneWidget);
    expect(onTheRow(find.text('idea')), findsOneWidget);
    expect(onTheRow(find.text('Cache the mirror.\nA second build fetches nothing.')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
    final task = World.backend.tasksNow.firstWhere((task) => task.name == work);
    expect(World.settings.reportsSeen(World.machines.current.name, work, reportsRunOf(task)), 1);
  });

  // Harm: a report forges a line of the window or turns its text around, so it reads as something it does not say.
  testWidgets('a report\'s control and direction characters are written out, never acted on', (tester) async {
    await reported(tester, [report(1, 'safe\u202Eevil\x1b[2J', kind: 'id\nea')]);

    await open(tester);

    expect(onTheRow(find.text(r'safe\u{202e}evil\u{001b}[2J')), findsOneWidget);
    expect(onTheRow(find.text(r'id\nea')), findsOneWidget);
  });

  // Harm: reports past the first page are never shown, or all are read at once.
  testWidgets('reports the machine left out are read on when asked, after the last one shown', (tester) async {
    await reported(tester, [report(1, 'one'), report(2, 'two'), report(3, 'three')]);
    World.backend.reportsPerAnswer = 2;

    await open(tester);
    expect(onTheRow(find.text('three')), findsNothing);
    expect(onTheRow(find.text('1 new report')), findsOneWidget, reason: 'the one not read yet is still new');
    final more = onTheRow(find.byKey(const Key('tile-reports-more')));
    // Mid-page: at the edge the status line lies over it.
    await Scrollable.ensureVisible(tester.element(more), alignment: 0.5);
    await tester.pump();
    await tester.tap(more);
    await World.settle(tester);

    expect(World.backend.reportsAsked, [(work, null), (work, 2)]);
    expect(onTheRow(find.text('three')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-more'))), findsNothing);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
  });

  // Harm: a report made while its row is open is not shown until the row is opened again.
  testWidgets('a new report while the row is open is read after the ones shown', (tester) async {
    await reported(tester, [report(1, 'one')]);
    await open(tester);

    World.backend.reportsOf[work] = [report(1, 'one'), report(2, 'two')];
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed), 'reports': 2, 'run': 'run-1'}));
    await World.settle(tester);

    expect(World.backend.reportsAsked, [(work, null), (work, 1)]);
    expect(onTheRow(find.text('two')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
  });

  // Harm: a machine that refuses to show reports reads as a task that made none.
  testWidgets('a refusal is said in the machine\'s words, never as no reports', (tester) async {
    await reported(tester, [report(1, 'one')]);
    World.backend.reportsRefusal = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchTask', {});

    await open(tester);

    expect(onTheRow(find.textContaining('Reports: The machine refused to show them: NoSuchTask')), findsOneWidget);
    expect(onTheRow(find.text('No reports')), findsNothing);
    expect(onTheRow(find.text('1 new report')), findsOneWidget, reason: 'nothing was seen');
  });

  // Harm: a task that made no reports is asked for them, or shows a count of none.
  testWidgets('a task with no reports asks nothing and says it has none', (tester) async {
    await reported(tester, const []);

    await open(tester);

    expect(World.backend.reportsAsked, isEmpty);
    expect(onTheRow(find.text('No reports')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
  });

  test('a report is cut past its bound, counting characters, never halves of one', () {
    expect(reportShown('a' * 10, most: 4), 'aaaa … cut');
    expect(reportShown('😀😀', most: 1), '😀 … cut');
    expect(reportShown('\ud800x'), r'\u{d800}x');
    expect(reportShown('ab\x07', most: 3), r'ab\u{0007}', reason: 'bounded before it is written out');
    expect(reportShown(String.fromCharCodes([0x200B, 0xE0041, 0xAD])), r'\u{200b}\u{e0041}\u{00ad}');
    expect(reportKindShown(String.fromCharCode(0x200B)), r'\u{200b}', reason: 'never a blank heading');
    expect(reportKindShown('  '), 'no kind');
  });

  // Harm: a refusal's own words forge a line of the window.
  test('a refusal\'s words are one line, its reason left out where it gives none', () {
    expect(
      reportsRefusedWords(const VarlinkException('org.fuin.porelo.Tasks1.Err\nForged', {'reason': ''})),
      r'The machine refused to show them: Err\nForged.',
    );
    expect(reportsRefusedWords(const FeatureNotSupported('Reports')), contains('needs a newer Porelo'));
  });

  // Harm: a refused read is asked again on every change of the window, or never again once the machine can answer.
  testWidgets('a refusal is not asked again by itself, and Try again asks anew', (tester) async {
    await reported(tester, [report(1, 'one')]);
    World.backend.reportsRefusal = const VarlinkException('org.fuin.porelo.Tasks1.Busy', {});
    await open(tester);
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed), 'phase': 'something else'}));
    await World.settle(tester);
    expect(World.backend.reportsAsked, hasLength(1));

    World.backend.reportsRefusal = null;
    final again = onTheRow(find.byKey(const Key('tile-reports-again')));
    await Scrollable.ensureVisible(tester.element(again), alignment: 0.5);
    await tester.pump();
    await tester.tap(again);
    await World.settle(tester);

    expect(World.backend.reportsAsked, hasLength(2));
    expect(onTheRow(find.text('one')), findsOneWidget);
  });

  // Harm: a report made while the reports are being read is never shown while the row stays open.
  testWidgets('a report made while a read is under way is read once it is done', (tester) async {
    await reported(tester, [report(1, 'one')]);
    World.backend.reportsHeld = Completer<void>();
    await open(tester);
    World.backend.reportsOf[work] = [report(1, 'one'), report(2, 'two')];
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed), 'reports': 2}));
    await World.settle(tester);

    World.backend.reportsHeld!.complete();
    World.backend.reportsHeld = null;
    await World.settle(tester);

    expect(onTheRow(find.text('two')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
  });

  // Harm: a machine that does not say how many reports a task made reads as one whose task made none.
  testWidgets('a row that does not say how many is asked when opened, and an older machine is said', (tester) async {
    await reported(tester, const []);
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed)}..remove('reports')));
    World.backend.reportsRefusal = const FeatureNotSupported('Reports');
    await World.settle(tester);

    await open(tester);

    expect(World.backend.reportsAsked, [(work, null)]);
    expect(onTheRow(find.textContaining('needs a newer Porelo')), findsOneWidget);
    expect(onTheRow(find.text('No reports')), findsNothing);
  });

  // Harm: reports the machine no longer keeps stay new for ever, or read as none ever made.
  testWidgets('reports the machine keeps no more are seen once read to the end, and said as not kept', (tester) async {
    await reported(tester, [report(3, 'three')]);
    World.backend.reportsOf[work] = [];
    World.backend.reportsLastOf[work] = 3;
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed), 'reports': 3}));
    await World.settle(tester);

    await open(tester);

    expect(onTheRow(find.text('No reports kept')), findsOneWidget);
    expect(onTheRow(find.byKey(const Key('tile-reports-new'))), findsNothing);
  });
}
