import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';

/// What a task a planner ordered says on its row: what it works on, and a build line only where it can have one.
void main() {
  const work = 'porelo-checkout-shell';

  /// The work's rows as a person reads them all: each unfolded, so a build line stands where it is said.
  Future<void> onTheWork(WidgetTester tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
  }

  Future<void> unfolded(WidgetTester tester) async {
    await toThePlace(tester, 'work');
    for (final row in workRows().evaluate().toList()) {
      final it = find.byWidget(row.widget);
      final fold = find.descendant(
        of: it,
        matching: find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'tile-fold ")),
      );
      if (fold.evaluate().isEmpty) continue;
      if (find.descendant(of: it, matching: find.byKey(const Key('tile-details'))).evaluate().isNotEmpty) continue;
      await tester.ensureVisible(fold.first);
      await tester.tap(fold.first);
      await tester.pump();
    }
    await World.settle(tester);
  }

  Finder said(String words) => find.descendant(of: workRows(), matching: find.text(words));

  /// The window as it stands once [work] was started for a planner's order of [role] over [issues] of ST366, handing
  /// back [result], and the machine reads its builds but has seen none.
  Future<void> plannedAs(
    WidgetTester tester, {
    required String role,
    String? result,
    List<String> issues = const ['PI68'],
  }) async {
    await onTheWork(tester);
    await World.settings.rememberPlanningOffer(
      machine: World.machines.all.first.name,
      container: work,
      offer: '00000000-0000-4000-8000-000000000589',
      provider: 'porelo-planner',
      project: 'checkout',
      story: 'ST366',
      task: 'pi',
      result: result,
      role: role,
      issues: issues,
    );
    World.backend.followBuilds(work, builds: const <Build>[], reader: 'github');
    await World.settle(tester);
    await unfolded(tester);
  }

  // Harm: a person reads an analysis as a build that has not run, or cannot tell which issue a task is for.
  testWidgets('an analysis says its issue, story and stage, and no build line before it pushed', (tester) async {
    await plannedAs(tester, role: 'MAIN', result: 'analysis.json');

    expect(said('PI68 of ST366, in analysis'), findsOneWidget);
    expect(said('No build yet'), findsNothing);
  });

  testWidgets('an estimate says its issues, story and stage, and no build line before it pushed', (tester) async {
    await plannedAs(tester, role: 'BUILDER', result: 'estimate.json', issues: ['PI68', 'PI69']);
    expect(said('PI68, PI69 of ST366, estimation'), findsOneWidget);
    expect(said('No build yet'), findsNothing);
  });

  testWidgets('a reader says it reads, and no build line before it pushed', (tester) async {
    await plannedAs(tester, role: 'READER');
    expect(said('PI68 of ST366, reading'), findsOneWidget);
    expect(said('No build yet'), findsNothing);
  });

  // Harm: work whose order names no stage reads as implementing, or loses the line that says its build has not run.
  testWidgets('work whose order names no stage says its issues and story alone, and its build line', (tester) async {
    await plannedAs(tester, role: 'MAIN');

    expect(said('PI68 of ST366'), findsOneWidget);
    expect(find.descendant(of: workRows(), matching: find.textContaining('implementing')), findsNothing);
    expect(said('No build yet'), findsOneWidget);
  });

  /// The fact of the gate on the work's own row.
  Finder gateFact() =>
      find.descendant(of: tileFor(work), matching: find.byKey(const ValueKey<String>('tile-fact gate')));

  // Harm: a task with no gate and nothing to push is said to have commits at a gate, or a build that has not run.
  testWidgets('a task the machine lists without the right to push says nothing of a gate or a build', (tester) async {
    await onTheWork(tester);
    final listed = World.backend.tasksNow.firstWhere((task) => task.name == work);
    World.backend.bringsUp(Task.from({...wire(listed), 'workspace': 'readOnly', 'rights': <String>[]}));
    World.backend.followBuilds(work, builds: const <Build>[], reader: 'github');
    await World.settle(tester);
    await unfolded(tester);

    expect(said('No build yet'), findsNothing);
    expect(gateFact(), findsNothing);
    expect(find.descendant(of: tileFor(work), matching: find.text('Commits at the gate')), findsNothing);
  });

  // Harm: a planned stage on a machine that does not say its rights is said to have commits at a gate.
  testWidgets('a planned stage handing back a result says nothing of a gate, its rights said or not', (tester) async {
    await plannedAs(tester, role: 'MAIN', result: 'analysis.json');

    expect(gateFact(), findsNothing);
    expect(said('No build yet'), findsNothing);
  });

  // Harm: work that may push loses the fact of its gate.
  testWidgets('work that may push says its gate as before', (tester) async {
    await plannedAs(tester, role: 'MAIN');

    expect(gateFact(), findsOneWidget);
    expect(said('No build yet'), findsOneWidget);
  });

  // Harm: work no planner ordered, or one an earlier build kept, gains a line it cannot fill, or loses its build line.
  testWidgets('work no planner ordered here says nothing more, and its build line as before', (tester) async {
    await onTheWork(tester);
    World.backend.followBuilds(work, builds: const <Build>[], reader: 'github');
    await World.settle(tester);
    await unfolded(tester);

    expect(find.byKey(const Key('tile-works-on')), findsNothing);
    expect(said('No build yet'), findsOneWidget);
  });
}
