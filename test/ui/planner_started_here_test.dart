import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/page_words.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

/// The planning of the test's machines, saying the planner that answers is one the window started, or not.
class _Started extends ChangeNotifier implements PlanningClient, StartedItsPlanner {
  _Started(this.inner) {
    inner.addListener(notifyListeners);
  }

  final PlanningClient inner;

  @override
  String? startedProgram;

  /// Changes what it says it started, as the window's planner does when its planner starts, ends or is replaced.
  void started(String? program) {
    startedProgram = program;
    notifyListeners();
  }

  @override
  List<PlanningProvider> get providers => inner.providers;

  @override
  String? get currentProvider => inner.currentProvider;

  @override
  String? get chosenProject => inner.chosenProject;

  @override
  Future<void> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
    PlanningStartRefusal? refusal,
  }) => inner.taskEvent(project, task, event, offer: offer, container: container, machine: machine, ended: ended);

  @override
  void dispose() {
    inner.removeListener(notifyListeners);
    super.dispose();
  }
}

void main() {
  const program = '/usr/libexec/porelo/planner';
  final note = find.text('No planner was serving, so the window started $program.');

  Future<_Started> open(WidgetTester tester, {String? started}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late _Started client;
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      planning: (machines) {
        final given = World.planningOf(machines);
        client = _Started(given.client)..startedProgram = started;
        addTearDown(client.dispose);
        return EmbeddedPlanning(client, startTask: given.startTask, startedOn: given.startedOn);
      },
    );
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(find.byType(PlanningScreen), findsOneWidget);
    return client;
  }

  /// Closes the board's info, as it is after its first showing, and opens it again when [again].
  Future<void> info(WidgetTester tester, {required bool again}) async {
    World.settings.setExplanationOpen('planning', open: false);
    await World.settle(tester);
    if (!again) return;
    await tester.tap(find.byKey(const ValueKey('explanation-open planning')));
    await World.settle(tester);
  }

  // Harm: a lasting line above every planning page, where a person looks for their stories, says once more what was
  // said once; and a person who expected a planner of their own cannot find which one answers.
  testWidgets("the window's start of the planner is said in the board's info, not above every page", (tester) async {
    await open(tester, started: program);

    await info(tester, again: false);
    expect(note, findsNothing);

    await info(tester, again: true);
    expect(note, findsOneWidget);
    for (final part in pageWords['planning']!) {
      expect(find.text(part.title), findsOneWidget);
      expect(find.text(part.words), findsOneWidget);
    }
  });

  // Harm: a person who saw Planning's info before never learns that the planner answering is one the window started;
  // and an info closed after it opens again on every page.
  testWidgets("a start by the window opens the info once more, which stays closed once it is closed", (tester) async {
    final client = await open(tester);
    await World.settings.markExplanationSeen('planning');
    await info(tester, again: false);
    World.shell.goTo(Section.work);
    await World.settle(tester);

    client.started(program);
    await World.settle(tester);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(note, findsOneWidget, reason: 'the info opened once more for the start');

    await info(tester, again: false);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(note, findsNothing, reason: 'closed, it stays closed');
  });

  // Harm: a planner the person runs themselves is said to be one the window started.
  testWidgets('a planner the window found running gets no such words', (tester) async {
    await open(tester);

    await info(tester, again: true);
    expect(find.textContaining('No planner was serving'), findsNothing);
  });

  // Harm: the words stay after the planner the window started ended or another took its place.
  testWidgets('the words go once the planner that answers is no longer the one the window started', (tester) async {
    final client = await open(tester, started: program);
    await info(tester, again: true);
    expect(note, findsOneWidget);

    client.started(null);
    await World.settle(tester);

    expect(note, findsNothing);
  });
}
