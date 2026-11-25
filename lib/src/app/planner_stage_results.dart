import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart' show PlannerProjects;

import 'planner_post.dart';

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
const mostStageResultBytes = 1024 * 1024;

/// The most bytes the hand-in's body may have: the file and 4096 for its offer and the JSON around it. The planner
/// answers a larger body as an unsigned call, so it is never sent.
const mostStageResultBody = mostStageResultBytes + 4096;

/// The most characters of the line that says why there is no result.
const mostMissingCharacters = 300;

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
  final why = missing == null || missing.length <= mostMissingCharacters
      ? missing
      : '${missing.substring(0, mostMissingCharacters - 1)}…';
  final body = <String, Object?>{'offer': offer, 'result': ?result, 'missing': ?why};
  if (utf8.encode(jsonEncode(body)).length > mostStageResultBody) {
    throw ArgumentError('A stage result over $mostStageResultBody bytes is handed in as missing, never sent.');
  }
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
    // A planner that could not be asked, or not proven, has not refused the result: its end waits and it is handed
    // in again, never reported as if the planner had answered.
    throw StageResultNotSaved(refusal.words, faults: refusal.faults, transient: true);
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
  if (status == 404 && problem['title'] == 'TaskNotAnswered') {
    throw StageResultNotSaved(plannerWords(status, problem), faults: faultsIn(problem));
  }
  if ((status == 404 || status == 405) && problem['title'] != 'NoSuchProject') {
    throw const StageResultNotSaved('this planner cannot take a stage\'s result; it needs a newer planner');
  }
  throw StageResultNotSaved(
    plannerWords(status, problem),
    faults: faultsIn(problem),
    // A project the planner was given and still does not know may be settling after its start.
    transient: status == 503 || status == 504 || problem['title'] == 'NoSuchProject',
  );
}
