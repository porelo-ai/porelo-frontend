import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_planning/porelo_planning.dart';

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
  await _onTheBoard(tester);
  World.shell.goTo(Section.work);
  await World.settle(tester);
}

/// The window on the stand-in's planning board.
Future<void> _onTheBoard(WidgetTester tester) async {
  await aBackendWithPlanningDetails(tester);
  await World.startApp(tester);
  await tester.tap(find.byKey(const Key('rail planning')));
  await World.settle(tester);
}

/// The planning board shown in the window's Planning, with no story or issue open over it.
void _expectBoard() {
  expect(World.shell.section, Section.planning);
  expect(World.shell.place.story, isNull);
  expect(planningElement('board'), findsOneWidget);
  expect(planningElement('detail'), findsNothing);
}

void main() {
  // Harm: a story found from elsewhere in the window opens outside the window's history, so the back key strands it.
  testWidgets('the finder opens a story from Work, and the back key leads to the board', (tester) async {
    await _fromWork(tester);

    await _find(tester, 'Open story ST291');

    expect(World.shell.section, Section.planning);
    await expectPlanningCrumbs(tester, 'Planning,ST291');
    expectPlanningDetail('Story source');
    expectPlanningDetail('# Story source', present: false);
    await planningBack(tester);
    _expectBoard();
  });

  // Harm: a page in Planning carries two titles, the window's own *Planning* head above the screen's head or breadcrumb.
  testWidgets('a planning page has one title, with the window\'s i in the screen\'s own head', (tester) async {
    void expectOneTitle(Finder page, {required bool board}) {
      expect(find.byType(PageHead), findsNothing, reason: 'the screen\'s head or breadcrumb is the one title');
      expect(find.descendant(of: page, matching: find.text('Planning')), findsOneWidget);
      final info = find.descendant(of: page, matching: find.byKey(const ValueKey<String>('explanation-open planning')));
      expect(info, findsOneWidget, reason: 'the i stands in the screen');
      // On the board beside the screen's Planning head; on a detail page at the end of its breadcrumb.
      final line = find.ancestor(of: info, matching: find.byType(board ? Row : Wrap)).first;
      expect(
        find.descendant(of: line, matching: board ? find.text('Planning') : find.byKey(const Key('planning-crumb 0'))),
        findsOneWidget,
      );
    }

    await _fromWork(tester);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expectOneTitle(find.byType(PlanningScreen), board: true);
    await _find(tester, 'Open story ST291');
    expectOneTitle(planningElement('detail'), board: false);
    await _find(tester, 'Open issue B541');
    expectOneTitle(planningElement('detail'), board: false);
  });

  // Harm: a page's first-time words stand above its title, so the page reads from its middle.
  testWidgets('planning\'s first-time words stand under the screen\'s head', (tester) async {
    await _onTheBoard(tester);
    final words = find.byKey(const ValueKey<String>('explanation planning'));
    expect(find.descendant(of: find.byType(PlanningScreen), matching: words), findsOneWidget);
    final head = find.descendant(of: find.byType(PlanningScreen), matching: find.text('Planning')).first;
    expect(tester.getTopLeft(words).dy, greaterThanOrEqualTo(tester.getBottomLeft(head).dy));
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
    _expectBoard();
  });

  // Harm: the back key retraces the path that led to a story, reopening an issue or another story instead of the board.
  testWidgets('the back key on a story reached through its issue\'s breadcrumb leads to the board, not the issue', (
    tester,
  ) async {
    await _onTheBoard(tester);
    await tapPlanning(tester, planningElement('story ST291'));
    await tapPlanning(tester, planningElement('issue B541'));
    await expectPlanningCrumbs(tester, 'Planning,ST291,B541');

    await tapPlanning(tester, planningElement('crumb 1'));
    await expectPlanningCrumbs(tester, 'Planning,ST291');
    await planningBack(tester);

    _expectBoard();
  });

  // Harm: the back key on a story found from another story returns to that other story instead of the board.
  testWidgets('the back key on a story found from another story leads to the board', (tester) async {
    await _onTheBoard(tester);
    await tapPlanning(tester, planningElement('story ST294'));
    await expectPlanningCrumbs(tester, 'Planning,ST294');

    await _find(tester, 'Open story ST291');
    await expectPlanningCrumbs(tester, 'Planning,ST291');
    await planningBack(tester);

    _expectBoard();
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
