import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart' show PlannerNotProven, PlanningRefusal;

import 'planner_call.dart';
import 'window_log.dart';

/// Tells the planner of this account to log at [level] from now on, and answers the level its log is at then.
typedef TellPlannerLevel = Future<LogLevel> Function(LogLevel level, {String? runtimeDirectory});

/// Why the planner did not take a level, in words: its own where it gave some.
class PlannerLevelRefused implements Exception {
  /// Takes the words.
  const PlannerLevelRefused(this.words);

  /// What went wrong, for a person.
  final String words;

  @override
  String toString() => words;
}

/// The planner's `PUT /log/level`, at the address its `planner.json` under [runtimeDirectory] names: the body
/// `{"level": ...}`, one of ERROR, WARN, INFO and DEBUG, answered with the level in force.
///
/// Through [callOwnPlanner]: signed under the address file's token, only to a listener that proved it, never through a
/// proxy; an answer is waited for [within].
Future<LogLevel> tellPlannerLevel(
  LogLevel level, {
  String? runtimeDirectory,
  Duration within = const Duration(seconds: 10),
}) async {
  try {
    final answer = await callOwnPlanner(
      'PUT',
      const ['log', 'level'],
      json: {'level': level.word},
      runtimeDirectory: runtimeDirectory,
      within: within,
      maxBody: 64 * 1024,
    );
    return plannerLevelAnswered(answer.status, utf8.decode(answer.body, allowMalformed: true));
  } on PlannerNotProven catch (notProven) {
    throw PlannerLevelRefused(notProven.description);
  } on PlanningRefusal catch (refusal) {
    throw switch (refusal.name) {
      'TimedOut' => PlannerLevelRefused('the planner did not answer within ${within.inSeconds} s'),
      _ => PlannerLevelRefused('$refusal'),
    };
  }
}

/// The level in force the planner answered with [status] and [body]: a refusal in the planner's words, and a planner
/// that does not know `/log/level` yet said as such.
LogLevel plannerLevelAnswered(int status, String body) {
  final Object? json;
  try {
    json = body.isEmpty ? null : jsonDecode(body);
  } on FormatException {
    throw PlannerLevelRefused('the planner answered $status with no JSON');
  }
  if (status == 404) throw const PlannerLevelRefused('this planner cannot set its log level; it needs a newer planner');
  if (status != 200) {
    final detail = json is Map<String, dynamic> ? json['detail'] ?? json['title'] : null;
    throw PlannerLevelRefused(detail is String ? detail : 'the planner answered $status');
  }
  final word = json is Map<String, dynamic> ? json['level'] : null;
  return LogLevel.values.where((each) => each.word == word).firstOrNull ??
      (throw PlannerLevelRefused('the planner answered the level ${word ?? 'none'}, which the window does not know'));
}
