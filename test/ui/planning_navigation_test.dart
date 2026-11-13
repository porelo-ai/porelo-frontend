import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';
import 'package:porelo_planning/planning_fake.dart' show mockRefusal;
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

Future<WorkView> _pendingPlanning(WidgetTester tester) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = [
    Project.from({'name': 'checkout'}),
  ];
  World.planning.boards['checkout'] = {
    'states': [
      {'name': 'Ready', 'kind': 'WAITING'},
      {'name': 'Review', 'kind': 'WAITING'},
    ],
    'phases': [
      {
        'name': 'Work',
        'states': ['Ready', 'Review'],
      },
    ],
    'stories': [
      {'id': 'StoryOne', 'title': 'A pending story', 'state': 'Ready', 'issues': <Map<String, dynamic>>[]},
    ],
    'revision': 'initial',
  };
  // A move is saved at once; one the planner answers late is the move still out that leaving asks about.
  World.planning.moveFailure = mockRefusal('TimedOut', const {});
  await World.startApp(tester);
  final work = tester.widget<WorkPage>(find.byType(WorkPage)).view;
  World.shell.goTo(Section.planning);
  await World.settle(tester);
  final board = tester.widget<PlanningScreen>(find.byType(PlanningScreen)).boards.selected!;
  unawaited(board.move('StoryOne', 'Review'));
  await World.settle(tester);
  expect(board.pending, isNotEmpty, reason: 'the move the planner has not answered is still awaited');
  expect(board.saving, isFalse, reason: 'only a move no longer saved may be left');
  return work;
}

void main() {
  // Harm: a canceled rail action changes the work filter before permission to leave is given.
  testWidgets('rail navigation preserves the work filter on cancel and clears it on confirmed navigation', (
    tester,
  ) async {
    final work = await _pendingPlanning(tester);
    work.search.text = 'keep-this-filter';
    final rail = tester.widget<ShellRail>(find.byType(ShellRail));
    rail.onGo(Section.work);
    await World.settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(work.search.text, 'keep-this-filter');
    await tester.tap(find.byKey(const Key('planning-stay')));
    await World.settle(tester);
    expect(find.byType(PlanningScreen), findsOneWidget);
    expect(work.search.text, 'keep-this-filter');
    rail.onGo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('planning-leave')));
    await World.settle(tester);
    expect(find.byType(WorkPage), findsOneWidget);
    expect(work.search.text, isEmpty);
  });

  // Harm: task navigation bypasses a leave refusal or loses the requested detail after resuming.
  testWidgets('opening planning work changes selection and opens detail only after confirming leave', (tester) async {
    await _pendingPlanning(tester);
    final view = tester.widget<PlanningScreen>(find.byType(PlanningScreen));
    final board = view.boards.selected!;
    final fleet = World.machines.fleet;
    final prior = fleet.selectedTask;
    view.taskChanges.open(board, 'porelo-checkout-migrate');
    await World.settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(World.shell.detailOpen, isFalse);
    expect(fleet.selectedTask, same(prior));
    await tester.tap(find.byKey(const Key('planning-stay')));
    await World.settle(tester);
    expect(World.shell.section, Section.planning);
    expect(World.shell.detailOpen, isFalse);
    expect(fleet.selectedTask, same(prior));
    view.taskChanges.open(board, 'porelo-checkout-migrate');
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('planning-leave')));
    await World.settle(tester);
    expect(World.shell.section, Section.work);
    expect(World.shell.detailOpen, isTrue);
    expect(fleet.selectedTask!.name, 'porelo-checkout-migrate');
    expect(board.pending, isNotEmpty);
  });

  // Harm: a finder selection loses its highlighted command while deferred navigation resumes.
  testWidgets('a confirmed finder navigation opens and highlights the selected machine command', (tester) async {
    await _pendingPlanning(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('command-query')), 'Show the vault');
    await World.settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Show the vault'));
    await World.settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(PlanningScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('planning-leave')));
    await World.settle(tester);
    final highlighted = find.byKey(const Key('highlighted'));
    expect(highlighted, findsOneWidget);
    expect(tester.widget<PopupMenuItem<String>>(highlighted).value, 'vault.show');
    expect(find.descendant(of: highlighted, matching: find.text('Show the vault')), findsOneWidget);
  });
}
