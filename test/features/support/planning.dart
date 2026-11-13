import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

import 'world.dart';

/// An independently mutable snapshot, with the exact design story set.
Map<String, dynamic> planningFixture() {
  final board = mockPlanningBoard();
  // The Reworking rule names the agents a rework may run with, as a planner's project file gives them; the screen's
  // board names none, which leaves its Rework dialog nothing to send.
  for (final rule in planningMaps(board, 'work').where((rule) => rule['state'] == 'Reworking')) {
    rule['models'] = <String, dynamic>{'pi': 'z-ai/glm-5.3-flash'};
  }
  return board;
}

/// The planning one machine serves: the screen's stand-in, which also warns of a story's running work before a move
/// and, once the move is confirmed, stops that run and names its tasks at work, as the planner does.
class WindowPlanningSource extends MockPlanningSource {
  /// Takes the machine's name.
  WindowPlanningSource(super.label);

  /// The board the planner's store holds once a save is refused, as after a push one repository refused; null leaves
  /// the board as it was.
  Map<String, dynamic>? heldWhenRefused;

  /// Each run a confirmed save stopped, as the save named it.
  final List<Map<String, dynamic>> stopped = [];

  @override
  Future<PlanningMovePreview> previewMoves(String project, List<PlanningMove> moves, String revision) async {
    final preview = await super.previewMoves(project, moves, revision);
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
      issues: preview.issues,
      warnings: [...preview.warnings, ...running],
    );
  }

  @override
  Future<PlanningMoveResult> saveMoves(
    String project,
    List<PlanningMove> moves,
    String revision, {
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
      reply = await super.saveMoves(project, moves, revision, digest: digest, confirm: confirm);
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
