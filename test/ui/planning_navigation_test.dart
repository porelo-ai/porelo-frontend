import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_view.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';

import '../features/support/world.dart';

Future<WorkView> _pendingPlanning(WidgetTester tester) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = [
    Project.from({'name': 'checkout'}),
  ];
  World.backend.planning['checkout'] = {
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
  await World.startApp(tester);
  final work = tester.widget<WorkPage>(find.byType(WorkPage)).view;
  World.shell.goTo(Section.planning);
  await World.settle(tester);
  tester.widget<PlanningView>(find.byType(PlanningView)).boards.selected!.move('StoryOne', 'Review');
  await World.settle(tester);
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
    expect(find.byType(PlanningView), findsOneWidget);
    expect(work.search.text, 'keep-this-filter');
    rail.onGo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('planning-leave')));
    await World.settle(tester);
    expect(find.byType(WorkPage), findsOneWidget);
    expect(work.search.text, isEmpty);
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
    expect(find.byType(PlanningView), findsOneWidget);
    await tester.tap(find.byKey(const Key('planning-leave')));
    await World.settle(tester);
    final highlighted = find.byKey(const Key('highlighted'));
    expect(highlighted, findsOneWidget);
    expect(tester.widget<PopupMenuItem<String>>(highlighted).value, 'vault.show');
    expect(find.descendant(of: highlighted, matching: find.text('Show the vault')), findsOneWidget);
  });
}
