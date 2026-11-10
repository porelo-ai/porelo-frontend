import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/a_backend_with_planning_details.dart';
import '../features/support/planning.dart';
import '../features/support/planning_details.dart';
import '../features/support/world.dart';

/// Finds [words] in the window's finder and runs it.
Future<void> _find(WidgetTester tester, String words) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await World.settle(tester);
  await tester.enterText(find.byKey(const Key('command-query')), words);
  await World.settle(tester);
  await tester.tap(find.widgetWithText(ListTile, words));
  await World.settle(tester);
}

/// The window with the stand-in's planning board read once, then left for Work.
Future<void> _fromWork(WidgetTester tester) async {
  await aBackendWithPlanningDetails(tester);
  await World.startApp(tester);
  await tester.tap(find.byKey(const Key('rail planning')));
  await World.settle(tester);
  World.shell.goTo(Section.work);
  await World.settle(tester);
}

void main() {
  // Harm: a story found from elsewhere in the window opens outside the window's history, so the back key strands it.
  testWidgets('the finder opens a story from Work, and the back key leads to the board', (tester) async {
    await _fromWork(tester);

    await _find(tester, 'Open story ST291');

    expect(World.shell.section, Section.planning);
    await expectPlanningCrumbs(tester, 'Planning,ST291');
    expectPlanningDetail('# Story source');
    await planningBack(tester);
    expect(World.shell.place.story, isNull);
    expect(planningElement('detail'), findsNothing);
  });

  // Harm: an issue found from elsewhere skips its story on the way back.
  testWidgets('the finder opens an issue from Work, and the back key leads to its story, then the board', (
    tester,
  ) async {
    await _fromWork(tester);

    await _find(tester, 'Open issue B541');

    await expectPlanningCrumbs(tester, 'Planning,ST291,B541');
    expectPlanningDetail('Only confirmed work is published');
    await planningBack(tester);
    await expectPlanningCrumbs(tester, 'Planning,ST291');
    await planningBack(tester);
    expect(World.shell.place.story, isNull);
  });

  // Harm: a web page found in the finder is opened past the window's opener, or at an address the machine never gave.
  testWidgets('the finder opens an issue\'s web page through the window\'s opener, at the machine\'s address', (
    tester,
  ) async {
    // The window's opener, which the world records in place of the desktop's.
    await _fromWork(tester);

    await _find(tester, 'Open issue B541 in browser');

    expect(World.opened, [Uri.parse('https://example.org/issues/B541')]);
  });
}
