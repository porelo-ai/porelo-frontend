import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a window that reaches no planner shows an empty board, or a board of its own, as if it planned.
  testWidgets('a window without planning says where planning comes from and shows no board', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, planningServed: false);

    World.shell.goTo(Section.planning);
    await World.settle(tester);

    expect(find.text(planningNotReached), findsOneWidget);
    expect(find.byType(PlanningScreen), findsNothing);
    expect(find.byKey(const ValueKey('rail planning')), findsOneWidget, reason: 'the rail keeps the place');
    expect(find.byKey(const Key('rail-planning-count')), findsNothing, reason: 'nothing is counted without a planner');
  });

  // Harm: the planning a window was given is hidden behind the line for a window without one.
  testWidgets('a window given planning shows its board and not the line', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);

    World.shell.goTo(Section.planning);
    await World.settle(tester);

    expect(find.byType(PlanningScreen), findsOneWidget);
    expect(find.text(planningNotReached), findsNothing);
  });

  // Harm: a window whose computer has no planner shows an empty board as if planning had nothing, or counts nothing as 0.
  testWidgets('a window whose planner is not installed says so in the planning place and shows no board', (
    tester,
  ) async {
    final runtime = Directory.systemTemp.createTempSync('planner-runtime-');
    Process.runSync('chmod', ['700', runtime.path]);
    addTearDown(() => runtime.deleteSync(recursive: true));
    late LocalPlanner planner;
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      planning: (machines) => plannerPlanning(
        planner = LocalPlanner.of(
          machines,
          runtimeDirectory: runtime.path,
          candidates: ['${runtime.path}/porelo-planner'],
          start: (_, _) async => fail('no planner may be started'),
        ),
      ),
    );
    addTearDown(planner.dispose);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(find.text(plannerLookedFor), findsOneWidget, reason: 'the place says it looks before it knows');

    await tester.runAsync(planner.reach);
    await World.settle(tester);

    expect(find.text(plannerNotInstalled), findsOneWidget);
    expect(find.byType(PlanningScreen), findsNothing);
    expect(find.byKey(const Key('rail-planning-count')), findsNothing, reason: 'nothing is counted without a planner');
  }, skip: Platform.isWindows); // Linux only: porelo-planner, its runtime directory and POSIX modes.

  // Harm: a planner the window reached stays hidden behind the line, so its boards are never shown.
  testWidgets('a window that reaches its planner shows the planning screen in place of the line', (tester) async {
    final runtime = Directory.systemTemp.createTempSync('planner-runtime-');
    Process.runSync('chmod', ['700', runtime.path]);
    addTearDown(() => runtime.deleteSync(recursive: true));
    final directory = Directory('${runtime.path}/porelo-planner')..createSync();
    Process.runSync('chmod', ['700', directory.path]);
    final address = File('${directory.path}/planner.json')..writeAsStringSync(jsonEncode({'port': 9, 'token': 't'}));
    Process.runSync('chmod', ['600', address.path]);
    final planner = LocalPlanner(
      projects: () => const [],
      repositories: (project) => throw StateError('no project is read'),
      runtimeDirectory: runtime.path,
      candidates: const [],
    );
    addTearDown(planner.dispose);
    await World.startBackend(World.work);
    await World.startApp(tester, planning: (_) => plannerPlanning(planner));
    World.shell.goTo(Section.planning);

    await tester.runAsync(planner.reach);
    await World.settle(tester);

    expect(find.byType(PlanningScreen), findsOneWidget);
    expect(find.byKey(const Key('planning-not-reached')), findsNothing);
  }, skip: Platform.isWindows); // Linux only: porelo-planner, its runtime directory and POSIX modes.

  // Harm: a planner that was not reached at the start stays unreached until the window is restarted.
  testWidgets('refreshing tries a planner not yet reached again', (tester) async {
    final planner = _Unreached();
    addTearDown(planner.dispose);
    await World.startBackend(World.work);
    await World.startApp(tester, planning: (_) => EmbeddedPlanning(planner, startTask: plannerStartTask));
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(find.text(plannerNotInstalled), findsOneWidget);

    await World.tapInView(tester, 'refresh-all');
    await World.settle(tester);

    expect(planner.reaches, 1);
  });
}

/// A planner the window has not reached, which counts how often it is asked to try again.
class _Unreached extends ChangeNotifier implements PlanningClient, PlanningReach {
  int reaches = 0;

  @override
  String? get notReached => plannerNotInstalled;

  @override
  Future<void> reach() async => reaches++;

  @override
  List<PlanningProvider> get providers => const [];

  @override
  String? get currentProvider => null;

  @override
  String? get chosenProject => null;

  @override
  Future<void> taskEvent(String project, String task, PlanningTaskEvent event) async {}
}
