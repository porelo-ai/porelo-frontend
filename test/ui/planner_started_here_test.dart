import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
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
  }) => inner.taskEvent(project, task, event, offer: offer, container: container, machine: machine, ended: ended);

  @override
  void dispose() {
    inner.removeListener(notifyListeners);
    super.dispose();
  }
}

void main() {
  const program = '/usr/libexec/porelo/planner';
  final line = find.byKey(const Key('planning-started-here'));

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

  // Harm: a person who expected a planner of their own reads the board of another one the window started, and takes
  // its failures for their own planner's.
  testWidgets('Planning says the window started the planner that answers, and which program', (tester) async {
    await open(tester, started: program);

    expect(line, findsOneWidget);
    expect(find.text('No planner was serving, so the window started $program.'), findsOneWidget);
  });

  // Harm: a planner the person runs themselves is said to be one the window started.
  testWidgets('a planner the window found running gets no such line', (tester) async {
    await open(tester);

    expect(line, findsNothing);
  });

  // Harm: the line stays after the planner the window started ended or another took its place.
  testWidgets('the line goes once the planner that answers is no longer the one the window started', (tester) async {
    final client = await open(tester, started: program);
    expect(line, findsOneWidget);

    client.started(null);
    await World.settle(tester);

    expect(line, findsNothing);
  });
}
