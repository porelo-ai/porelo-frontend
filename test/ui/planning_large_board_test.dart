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

/// The cards built in the lane of state Idea.
final _ideaCards = find.descendant(
  of: find.byKey(const Key('planning-state Idea'), skipOffstage: false),
  matching: find.byWidgetPredicate(
    (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('planning-card '),
  ),
);

/// The wall time, in milliseconds, of a click on Planning until the board stands, and of folding and unfolding the
/// lane of state Idea on it. Only the click and its pumps are timed; that the lane folded and came back is checked
/// between them, so a tap that missed cannot pass as a fast fold.
Future<({int open, int fold})> _openAndFold(WidgetTester tester) async {
  final open = await _timed(() async {
    await tester.tap(find.byKey(const Key('rail planning')));
    await World.settle(tester);
  });
  expect(find.byKey(const Key('planning-board')), findsOneWidget);
  final button = find.byKey(const Key('planning-fold-state Idea'));
  expect(button.hitTestable(), findsOneWidget);
  expect(_ideaCards, findsWidgets, reason: 'the lane shows its cards before the fold');
  var fold = await _timed(() async {
    await tester.tap(button);
    await tester.pump();
  });
  expect(_ideaCards, findsNothing, reason: 'the lane is folded');
  fold += await _timed(() async {
    await tester.tap(button);
    await tester.pump();
  });
  expect(_ideaCards, findsWidgets, reason: 'the lane is unfolded again');
  return (open: open, fold: fold);
}

/// Three timed returns to Planning from Work, as their medians: one slow return on a busy host does not decide.
Future<({int open, int fold})> _medianOfThree(WidgetTester tester) async {
  final samples = <({int open, int fold})>[];
  for (var i = 0; i < 3; i++) {
    World.shell.goTo(Section.work);
    await World.settle(tester);
    samples.add(await _openAndFold(tester));
  }
  int median(Iterable<int> values) => (values.toList()..sort())[1];
  return (open: median(samples.map((sample) => sample.open)), fold: median(samples.map((sample) => sample.fold)));
}

void main() {
  // Harm: on a board of the porelo projects' size, opening Planning, again on every return to it, or folding a lane
  // holds the window's only thread for seconds, long enough that the desktop offers to end the window.
  //
  // Wall time in debug under `flutter test`, where a pump costs only its building, layout and painting, measured
  // against the stand-in's own board of 35 stories in the same run, after a first visit, so a busy host slows both
  // alike; each side is the median of three returns. A board that built and laid out every card of every lane at once
  // took 4.7 to 4.8 times as long to open as the small one (1613 against 338 ms) and 3.0 to 4.1 times as long to fold
  // and unfold a lane (624 against 211 ms). With only four cards built per lane it took 1.8 to 2.1 and 1.1 to 2.4 times
  // as long; the bounds stand between. The board that builds only what is in view takes 0.85 to 1.5 times as long to
  // open and 0.77 to 1.3 times to fold (three runs, medians).
  testWidgets('a board of 360 stories opens and folds a lane about as fast as a small one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await aBackendWithPlanningDetails(tester);
    await World.startApp(tester);
    // The first visit also pays for what any first build pays, such as compiling the screen's code.
    await _openAndFold(tester);
    final small = await _medianOfThree(tester);

    World.shell.goTo(Section.work);
    await World.settle(tester);
    final large = _largeBoard();
    World.planning.boards['checkout'] = large;
    World.planning.push('checkout', large);
    await World.settle(tester);
    // The large board is visited once untimed too, so both are timed on a return, warm alike.
    await _openAndFold(tester);
    final again = await _medianOfThree(tester);
    expect(find.byKey(const Key('planning-card ST1000')), findsOneWidget, reason: 'the large board is shown');

    final said =
        'small board: open ${small.open} ms, fold ${small.fold} ms; '
        'large board: open ${again.open} ms, fold ${again.fold} ms';
    expect(again.open, lessThan(small.open * 3), reason: said);
    expect(again.fold, lessThan(small.fold * 2.75), reason: said);
  });
}
