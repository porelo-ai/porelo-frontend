import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/a_backend_with_planning_details.dart';
import '../features/support/planning.dart';
import '../features/support/world.dart';

/// The stand-in's board grown to the size of the porelo projects' own: [stories] stories, each with [issues] issues,
/// spread over every state the board reports.
Map<String, dynamic> _largeBoard({int stories = 360, int issues = 4}) {
  final board = planningFixture();
  final states = [for (final state in planningMaps(board, 'states')) state['name'] as String];
  final template = planningMaps(board, 'stories').firstWhere((story) => (story['issues'] as List).isNotEmpty);
  final issue = (template['issues'] as List).cast<Map<String, dynamic>>().first;
  const priorities = ['Highest', 'High', 'Medium', 'Low'];
  board['stories'] = [
    for (var s = 0; s < stories; s++)
      {
        'id': 'ST${1000 + s}',
        'title': 'Story number $s of the large board, with a title as long as a real one is',
        'state': states[s % states.length],
        'priority': priorities[s % priorities.length],
        'link': 'https://example.org/stories/ST${1000 + s}',
        'description': '',
        'issues': [
          for (var i = 0; i < issues; i++)
            {...issue, 'id': 'PJ${10000 + s * issues + i}', 'title': 'Issue $i of story $s', 'state': 'Backlog'},
        ],
      },
  ];
  board['work'] = planningMaps(board, 'work');
  return board;
}

/// The wall time [run] takes, in milliseconds.
Future<int> _timed(Future<void> Function() run) async {
  final watch = Stopwatch()..start();
  await run();
  return watch.elapsedMilliseconds;
}

/// The wall time, in milliseconds, of a click on Planning until the board stands, and of folding and unfolding the
/// lane of state Idea on it.
Future<({int open, int fold})> _openAndFold(WidgetTester tester) async {
  final open = await _timed(() async {
    await tester.tap(find.byKey(const Key('rail planning')));
    await World.settle(tester);
  });
  expect(find.byKey(const Key('planning-board')), findsOneWidget);
  final fold = await _timed(() async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('planning-fold-state Idea')));
      await tester.pump();
    }
  });
  return (open: open, fold: fold);
}

void main() {
  // Harm: on a board of the porelo projects' size, opening Planning, again on every return to it, or folding a lane
  // holds the window's only thread for seconds, long enough that the desktop offers to end the window.
  //
  // Wall time in debug under `flutter test`, where a pump costs only its building, layout and painting, measured
  // against the stand-in's own board of 35 stories in the same run, after a first visit, so a busy host slows both
  // alike. Today the board builds and lays out every card of every lane at once: the large board took 4.7 to 4.8 times
  // as long to open as the small one (1613 against 338 ms) and 3.0 to 4.1 times as long to fold and unfold a lane
  // (624 against 211 ms). With only four cards built per lane, as a board that builds what is in view would, it took
  // 1.8 to 2.1 and 1.1 to 2.4 times as long; the bounds stand between.
  testWidgets(
    'a board of 360 stories opens and folds a lane about as fast as a small one',
    skip: true, // The board is the planning screen's own (porelo-planner): it must build only the cards in view.
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await aBackendWithPlanningDetails(tester);
      await World.startApp(tester);
      // The first visit also pays for what any first build pays, such as compiling the screen's code.
      await _openAndFold(tester);
      World.shell.goTo(Section.work);
      await World.settle(tester);
      final small = await _openAndFold(tester);

      World.shell.goTo(Section.work);
      await World.settle(tester);
      final large = _largeBoard();
      World.planning.boards['checkout'] = large;
      World.planning.push('checkout', large);
      await World.settle(tester);
      final again = await _openAndFold(tester);
      expect(find.byKey(const Key('planning-card ST1000')), findsOneWidget, reason: 'the large board is shown');

      final said =
          'small board: open ${small.open} ms, fold ${small.fold} ms; '
          'large board: open ${again.open} ms, fold ${again.fold} ms';
      expect(again.open, lessThan(small.open * 3), reason: said);
      expect(again.fold, lessThan(small.fold * 2.75), reason: said);
    },
  );
}
