import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningFilter, PlanningView;

void main() {
  Future<void> show(
    WidgetTester tester, {
    required ShellPlace place,
    Set<String> folded = const {'planning'},
    int? openWork,
    int? reviewing,
    double width = 1280,
    void Function(ShellPlace, bool)? onPlace,
  }) async {
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellRail(
            section: place.section,
            place: place,
            foldedOpen: folded,
            onPlace: onPlace,
            running: 0,
            work: 0,
            needing: 12,
            reviewing: reviewing,
            openWork: openWork,
            planning: 0,
            planningCounted: true,
            machines: 0,
            projects: 0,
            width: width < 600 ? width : 280,
            onGo: (_) {},
            onRefresh: () {},
            onStopEverywhere: null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final board = find.byKey(const ValueKey('rail planning-board'));
  final openWork = find.byKey(const ValueKey('rail planning-openWork'));
  const story = ShellPlace(Section.planning, project: 'checkout', planningSource: 'local', story: 'shop#12');

  // Harm: the board and the open work are found only by opening Planning and looking for a switch on the page, and a
  // story opened from a card leaves no row that leads back to it.
  testWidgets('Board and Open work stand under Planning, the open story under the view it came from', (tester) async {
    await show(tester, place: story, openWork: 7);

    expect(board, findsOneWidget);
    expect(find.descendant(of: board, matching: find.text('Board')), findsOneWidget);
    expect(find.descendant(of: openWork, matching: find.text('Open work')), findsOneWidget);
    expect(find.descendant(of: openWork, matching: find.text('7')), findsOneWidget);
    expect(find.text('› shop#12'), findsOneWidget);
    final boardTop = tester.getTopLeft(board).dy;
    final storyTop = tester.getTopLeft(find.text('› shop#12')).dy;
    expect(storyTop, greaterThan(boardTop));
    expect(storyTop, lessThan(tester.getTopLeft(openWork).dy), reason: 'the story stands under Board');
  });

  // Harm: the story row points to Open work while the story was opened from the board, so Back and the row disagree.
  testWidgets('a story opened from Open work stands under Open work', (tester) async {
    await show(
      tester,
      place: const ShellPlace(Section.planning, story: 'shop#12', planningView: PlanningView.openWork),
    );

    expect(tester.getTopLeft(find.text('› shop#12')).dy, greaterThan(tester.getTopLeft(openWork).dy));
  });

  // Harm: with Planning folded the rail highlights nothing, so the person cannot see where they are.
  testWidgets('a folded Planning stands selected for its views and story', (tester) async {
    await show(tester, place: story, folded: const {});

    expect(board, findsNothing);
    final planning = tester.element(find.byKey(const ValueKey('rail planning')));
    expect(planning.findAncestorWidgetOfExactType<Semantics>()?.properties.selected, isTrue);
  });

  // Harm: Left on Board leaves the keyboard below Planning, so the menu cannot be walked back up to it.
  testWidgets('Left on Board moves to Planning', (tester) async {
    final chosen = <ShellPlace>[];
    await show(
      tester,
      place: const ShellPlace(Section.planning, project: 'checkout'),
      onPlace: (place, _) => chosen.add(place),
    );

    await tester.tap(board);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(chosen.map((place) => place.project), ['checkout', null], reason: 'Board, then Planning itself');
  });

  // Harm: an unknown count reads as nothing left to build.
  testWidgets('Open work shows no count while the planner has not said', (tester) async {
    await show(tester, place: const ShellPlace(Section.planning));

    expect(find.descendant(of: openWork, matching: find.text('0')), findsNothing);
  });

  // Harm: the story row leads to the issue opened under it, or to a story of another view or filter.
  testWidgets('the story row leads back to the story with the view and filter it came from', (tester) async {
    ShellPlace? chosen;
    await show(
      tester,
      place: const ShellPlace(
        Section.planning,
        story: 'shop#12',
        issue: 'shop#13',
        planningFilter: PlanningFilter.review,
      ),
      onPlace: (place, _) => chosen = place,
    );

    await tester.tap(find.text('› shop#12'));
    await tester.pump();
    expect(chosen?.story, 'shop#12');
    expect(chosen?.issue, isNull);
    expect(chosen?.planningFilter, PlanningFilter.review);
  });

  // Harm: at a phone's width the review count pushes Needs you's name or badge out of sight.
  testWidgets('Needs you keeps its name, badge and review count at 390 wide', (tester) async {
    await show(tester, place: const ShellPlace(Section.attention), reviewing: 63, width: 390);

    final needsYou = find.byKey(const ValueKey('rail attention'));
    expect(find.descendant(of: needsYou, matching: find.text('Needs you')), findsOneWidget);
    expect(find.descendant(of: needsYou, matching: find.byKey(const Key('needing-count-badge'))), findsOneWidget);
    expect(find.descendant(of: needsYou, matching: find.text('63')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('navigation', () {
    const local = Machine(name: 'local', socketPath: '/run/porelo.sock');

    // Harm: Back from a story drops the filter, so the person lands on every story and loses the review list.
    test('Back from a story returns to the view and filter it was opened from', () {
      final shell = ShellModel()
        ..choosePlace(
          const ShellPlace(
            Section.planning,
            project: 'checkout',
            story: 'shop#12',
            planningView: PlanningView.openWork,
            planningFilter: PlanningFilter.review,
          ),
        )
        ..close();

      expect(shell.place.story, isNull);
      expect(shell.place.project, 'checkout');
      expect(shell.place.planningView, PlanningView.openWork);
      expect(shell.place.planningFilter, PlanningFilter.review);
    });

    // Harm: a story opened while Planning is folded leaves its row hidden, so nothing in the menu shows where one is.
    test('opening a story or a view unfolds Planning', () {
      final shell = ShellModel()..choosePlace(const ShellPlace(Section.planning, story: 'shop#12'));

      expect(shell.foldedOpen, contains('planning'));
    });

    // Harm: after a restart Open work is lost, or a view this build does not know names a row that is not there.
    test('a restart keeps the planning view and drops one it does not know', () {
      final before = ShellModel()
        ..restoreNavigation(const {}, const [local], local)
        ..choosePlace(const ShellPlace(Section.planning, planningView: PlanningView.openWork));
      final saved = before.navigation;

      final after = ShellModel()..restoreNavigation(saved, const [local], local);
      expect(after.place.planningView, PlanningView.openWork);
      expect(after.foldedOpen, contains('planning'));

      final unknown = ShellModel()..restoreNavigation({...saved, 'planningView': 'roadmap'}, const [local], local);
      expect(unknown.place.section, Section.planning);
      expect(unknown.place.planningView, PlanningView.board);
    });
  });
}
