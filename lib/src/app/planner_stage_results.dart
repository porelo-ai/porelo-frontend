import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart' show PlannerProjects;

import 'planner_ideas.dart';

/// Hands what the planned stage task [task] of [offer] in [project] produced to the planner of this account: its
/// [result] file's object, or [missing], one line of why there is none. Answers once the planner saved it.
typedef HandStageResult = Future<void> Function(
  String project,
  String task,
  String offer, {
  Map<String, Object?>? result,
  String? missing,
  String? runtimeDirectory,
  PlannerProjects? projects,
});

/// Why the planner did not save a stage's result.
class StageResultNotSaved extends PlannerDidNotSave {
  /// Takes the words, the faults the planner named, and whether trying again later may save it.
  const StageResultNotSaved(super.words, {super.faults, super.transient});
}

/// The most bytes a stage's result file may have, as the planner takes it.
const mostStageResultBytes = 262144;

/// The planner's `POST /projects/{project}/tasks/{task}/result`, signed as every call to it is: the body
/// `{"offer": ..., "result": <the file's object>}`, or `{"offer": ..., "missing": "<why>"}` where the task left none.
///
/// The planner answers each offer once and the same again after: a second hand-in of the same offer is answered with
/// the first outcome, so one the planner could not be reached for is handed in again later.
Future<void> handStageResult(
  String project,
  String task,
  String offer, {
  Map<String, Object?>? result,
  String? missing,
  String? runtimeDirectory,
  PlannerProjects? projects,
  Duration within = const Duration(seconds: 30),
}) async {
  if ((result == null) == (missing == null)) {
    throw ArgumentError('A stage hands in either its result or why it has none.');
  }
  final body = <String, Object?>{'offer': offer, 'result': ?result, 'missing': ?missing};
  final (int, String) answered;
  try {
    answered = await postToPlanner(
      project,
      ['projects', project, 'tasks', task, 'result'],
      body,
      runtimeDirectory: runtimeDirectory,
      projects: projects,
      within: within,
    );
  } on PlannerDidNotSave catch (refusal) {
    throw StageResultNotSaved(refusal.words, faults: refusal.faults, transient: refusal.transient);
  }
  stageResultAnswered(answered.$1, answered.$2);
}

/// Whether the planner saved a stage's result by its answer [status] and [body]: a refusal in the planner's words with
/// the faults it named, a planner that does not take stage results yet said as such, and a planner that cannot save
/// now marked transient.
void stageResultAnswered(int status, String body) {
  if (status >= 200 && status <= 299) return;
  Object? json;
  try {
    json = body.isEmpty ? null : jsonDecode(body);
  } on FormatException {
    json = null;
  }
  final problem = json is Map<String, dynamic> ? json : const <String, dynamic>{};
  if ((status == 404 || status == 405) && problem['title'] != 'NoSuchProject') {
    throw const StageResultNotSaved('this planner cannot take a stage\'s result; it needs a newer planner');
  }
  throw StageResultNotSaved(
    plannerWords(status, problem),
    faults: faultsIn(problem),
    transient: status == 503 || status == 504,
  );
}
