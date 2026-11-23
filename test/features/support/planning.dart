import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';
import 'package:porelo_frontend/src/app/report_at_planner.dart';

import 'world.dart';

/// An independently mutable snapshot, with the exact design story set.
///
/// ST291 waits in Backlog with all its issues there, as the planner derives an open story's state from its issues: the
/// scenarios that start its work or move it need a waiting story. [storyBuilt] puts the story under building instead,
/// its first two issues in Implementing, for the scenarios that move those issues.
Map<String, dynamic> planningFixture({bool storyBuilt = false}) {
  final board = mockPlanningBoard();
  // The Reworking rule names the agents a rework may run with, as a planner's project file gives them; the screen's
  // board names none, which leaves its Rework dialog nothing to send.
  for (final rule in planningMaps(board, 'work').where((rule) => rule['state'] == 'Reworking')) {
    rule['models'] = <String, dynamic>{'pi': 'z-ai/glm-5.3-flash'};
  }
  final story = planningMaps(board, 'stories').singleWhere((story) => story['id'] == 'ST291');
  story['state'] = storyBuilt ? 'Implementing' : 'Backlog';
  for (final issue in planningMaps(story, 'issues').where((issue) => {'B540', 'B541'}.contains(issue['id']))) {
    issue['state'] = storyBuilt ? 'Implementing' : 'Backlog';
  }
  return board;
}

/// Puts the story [id] of [board] and every issue of it in [state], as the planner serves a story that stands where
/// all its issues do.
void planningStoryStands(Map<String, dynamic> board, String id, String state) {
  final story = planningMaps(board, 'stories').singleWhere((story) => story['id'] == id);
  story['state'] = state;
  for (final issue in planningMaps(story, 'issues')) {
    issue['state'] = state;
  }
}

/// The planning one machine serves: the screen's stand-in, which also warns of a story's running work before a move
/// and, once the move is confirmed, stops that run and names its tasks at work, as the planner does.
class WindowPlanningSource extends MockPlanningSource implements TellsTaskReports {
  /// Takes the machine's name.
  WindowPlanningSource(super.label);

  /// The board the planner's store holds once a save is refused, as after a push one repository refused; null leaves
  /// the board as it was.
  Map<String, dynamic>? heldWhenRefused;

  /// Each run a confirmed save stopped, as the save named it.
  final List<Map<String, dynamic>> stopped = [];

  /// A follow-up order the answer to the next started report carries, as the planner orders a story's next task; null
  /// where answers order none.
  Map<String, dynamic>? followUpOnStart;

  /// Whether every started report's answer carries [followUpOnStart], not only the next one's.
  bool followUpEveryStart = false;

  /// Each report sent to this planner, by offer and event, in order.
  final List<(String, PlanningTaskEvent)> reported = [];

  /// Holds the next started report until completed, which answers it, or completed with an error, which the planner
  /// refuses it with; null where reports are answered at once.
  Completer<void>? holdNextStarted;

  /// The offer of the started report [holdNextStarted] held.
  String? heldOffer;

  /// What holds that report: completed, it is answered; completed with an error, the planner refuses it with that.
  Completer<void>? heldReport;

  @override
  Future<TaskEventResolution> taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) => ReportAtPlanner.told(
    offer,
    () => _taskEvent(
      project,
      task,
      event,
      offer: offer,
      container: container,
      machine: machine,
      ended: ended,
      landed: landed,
    ),
  );

  Future<TaskEventResolution> _taskEvent(
    String project,
    String task,
    PlanningTaskEvent event, {
    required String offer,
    required String container,
    required String machine,
    PlanningTaskEnded? ended,
    List<PlanningLanding> landed = const [],
  }) async {
    reported.add((offer, event));
    if (event == PlanningTaskEvent.started && holdNextStarted != null) {
      final hold = holdNextStarted!;
      holdNextStarted = null;
      heldOffer = offer;
      heldReport = hold;
      await hold.future;
    }
    final order = event == PlanningTaskEvent.started ? followUpOnStart : null;
    if (order == null) {
      return super.taskEvent(
        project,
        task,
        event,
        offer: offer,
        container: container,
        machine: machine,
        ended: ended,
        landed: landed,
      );
    }
    if (!followUpEveryStart) followUpOnStart = null;
    final answer = work.call('TaskEvent', {
      'project': project,
      'task': task,
      'event': 'STARTED',
      'offer': offer,
      'container': container,
      'machine': machine,
    });
    // A follow-up runs in the mode of the run it follows, as the planner orders it.
    final mode = (((answer['work'] as Map)['tasks'] as List).first as Map)['mode'];
    return TaskEventResolution.from({
      ...answer,
      'tasks': [
        {...order, 'mode': mode},
      ],
    });
  }

  @override
  Future<PlanningMovePreview> previewMoves(String project, List<PlanningMove> moves) async {
    final preview = await super.previewMoves(project, moves);
    final running = [
      for (final MapEntry(key: story, value: work) in _running(project, moves).entries)
        PlanningMoveWarning.from({
          'kind': PlanningMoveWarning.runningWork,
          'item': story,
          'run': work['run'],
          'tasks': [for (final task in _atWork(work)) task['task']],
        }),
    ];
    return PlanningMovePreview(
      revision: preview.revision,
      digest: preview.digest,
      targets: preview.targets,
      issues: preview.issues,
      warnings: [...preview.warnings, ...running],
    );
  }

  @override
  Future<PlanningMoveResult> saveMoves(
    String project,
    List<PlanningMove> moves,
    Map<String, String> seen, {
    required String digest,
    bool confirm = false,
  }) async {
    final running = _running(project, moves);
    if (running.isNotEmpty && !confirm) {
      throw mockRefusal('org.fuin.porelo.Tasks1.WorkRunning', {
        'story': running.keys.first,
        'detail': 'Work is running; a move that stops it must be confirmed.',
      });
    }
    final PlanningMoveResult reply;
    try {
      reply = await super.saveMoves(project, moves, seen, digest: digest, confirm: confirm);
    } on PlanningRefusal {
      if (heldWhenRefused case final held?) boards[project] = held;
      rethrow;
    }
    if (running.isEmpty) return reply;
    final named = [
      for (final MapEntry(key: story, value: work) in running.entries)
        {
          'story': story,
          'run': work['run'],
          'tasks': [
            for (final task in _atWork(work)) {'task': task['task'], 'containerId': task['containerId']},
          ],
        },
    ];
    // The saved board's copy of each run stops, as the planner records the stop with the save.
    for (final story in planningMaps(board(project), 'stories').where((story) => running.containsKey(story['id']))) {
      if (story['work'] case final Map<String, dynamic> work) {
        work['atWork'] = false;
        for (final task in _atWork(work)) {
          task['atWork'] = false;
        }
      }
    }
    stopped.addAll(named);
    return PlanningMoveResult.from({'revision': reply.revision, 'moved': reply.moved, 'stopped': named});
  }

  /// The run at work of each story [moves] moves, by story.
  Map<String, Map<String, dynamic>> _running(String project, List<PlanningMove> moves) {
    final ids = {
      for (final move in moves)
        if (move is PlanningStoryMove) move.story,
    };
    return {
      for (final story in planningMaps(board(project), 'stories'))
        if (story['work'] case final Map<String, dynamic> work
            when ids.contains(story['id']) && work['atWork'] == true && _atWork(work).isNotEmpty)
          story['id'] as String: work,
    };
  }

  static List<Map<String, dynamic>> _atWork(Map<String, dynamic> work) => [
    for (final task in (work['tasks'] as List? ?? const []).cast<Map<String, dynamic>>())
      if (task['atWork'] == true) task,
  ];
}

/// Pushes one complete answer for the scenario's known project.
Future<void> pushPlanning(WidgetTester tester, Map<String, dynamic> snapshot) async {
  World.planning.push('checkout', snapshot);
  await World.settle(tester);
}

/// The list of maps held by a snapshot.
List<Map<String, dynamic>> planningMaps(Map<String, dynamic> board, String field) =>
    (board[field] as List<dynamic>).cast<Map<String, dynamic>>();

/// A named planning element, required to exist before reading it.
Finder planningElement(String key) => find.byKey(Key('planning-$key'));

/// The plain text below one known planning element.
String planningText(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  return tester
      .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text), matchRoot: true))
      .map((text) => text.data ?? '')
      .join(' ');
}

/// The pointer held over a planning drop target until a scenario releases it.
TestGesture? planningDrag;
