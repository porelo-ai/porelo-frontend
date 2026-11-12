import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';

import '../support/e2e.dart';
import '../support/story_play.dart';

/// What the planning place shows once it is past looking for the planner: the board or its choice of project.
final theBoard = find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('planning-project') ||
      (widget is Text && (widget.data ?? '').startsWith('The stories of project ')),
);

/// The notes the planning place shows instead of a board where this computer gives it no planner.
final planningNotOffered = [plannerNotOnWindows, plannerNotInstalled];

/// Usage: I open Planning
Future<void> iOpenPlanning(WidgetTester tester) => played(
  tester,
  '2 the person opens Planning',
  () async {
    await toThePlace(tester, 'planning');
    String? note() => planningNotOffered.where((each) => find.text(each).evaluate().isNotEmpty).firstOrNull;
    await until(
      tester,
      () => theBoard.evaluate().isNotEmpty || note() != null,
      within: const Duration(minutes: 2),
      asked: () =>
          'asked for the board or its choice of project; on screen: '
          '${tester.widgetList<Text>(find.byType(Text)).map((each) => each.data).nonNulls.join(' / ')}',
    );
    if (note() case final said?) fail('asked for the board; the window says: $said');
  },
  leansOn: 'window-planner',
  goesOn: true,
);
