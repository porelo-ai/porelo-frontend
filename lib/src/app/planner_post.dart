import 'dart:convert';

import 'package:porelo_planning/porelo_planning.dart'
    show PlannerNotProven, PlannerProject, PlannerProjects, PlanningRefusal;

import 'planner_call.dart';
import '../wire/limit_factors.dart';

/// Why the planner did not save what the window handed it, in words: its own where it gave some.
class PlannerDidNotSave implements Exception {
  /// Takes the words, the faults the planner named, and whether trying again later may save it.
  const PlannerDidNotSave(this.words, {this.faults = const [], this.transient = false});

  /// What went wrong, for a person.
  final String words;

  /// The faults the planner named in what was handed, each starting with the field it names.
  final List<String> faults;

  /// Whether the planner could not be asked, or could not save it now, so a later try may save it.
  final bool transient;

  @override
  String toString() => faults.isEmpty ? words : '$words ${faults.join('; ')}';
}

/// Sends [body] as `POST` to [path] of the planner of this account, signed through [callOwnPlanner], and answers its
/// status and body. A planner that was not given [project] since it started (`NoSuchProject`) is given it, with the
/// repository [projects] names, as `PUT /projects/{project}`, and is asked once more, as the board's reads do. A planner
/// that cannot be asked is a [PlannerDidNotSave], transient where a later try may reach it.
Future<(int, String)> postToPlanner(
  String project,
  List<String> path,
  Map<String, Object?> body, {
  String? runtimeDirectory,
  PlannerProjects? projects,
  Duration within = const Duration(seconds: 30),
}) async {
  Future<(int, String)> send(String method, List<String> path, Map<String, Object?> json) async {
    final answer = await callOwnPlanner(
      method,
      path,
      json: json,
      runtimeDirectory: runtimeDirectory,
      within: within,
      maxBody: 256 * 1024,
    );
    return (answer.status, utf8.decode(answer.body, allowMalformed: true));
  }

  try {
    var (status, answer) = await send('POST', path, body);
    if (projects != null && status == 404 && _title(answer) == 'NoSuchProject') {
      final PlannerProject given;
      try {
        given = await projects(project);
      } on Object {
        throw PlannerDidNotSave('no watched machine names the repository of $project yet', transient: true);
      }
      final told = await send('PUT', ['projects', project], {'repository': given.repository, 'branch': ?given.branch});
      if (told.$1 < 200 || told.$1 > 299) return told;
      (status, answer) = await send('POST', path, body);
    }
    return (status, answer);
  } on PlannerNotProven catch (notProven) {
    throw PlannerDidNotSave(notProven.description);
  } on PlanningRefusal catch (refusal) {
    throw switch (refusal.name) {
      'NoAddress' || 'BadAddress' => const PlannerDidNotSave('no planner is running for this account', transient: true),
      'TimedOut' => PlannerDidNotSave(
        'the planner did not answer within ${serviceWait(within).inSeconds} s',
        transient: true,
      ),
      'PlannerUnreachable' => PlannerDidNotSave('$refusal', transient: true),
      _ => PlannerDidNotSave('$refusal'),
    };
  }
}

String? _title(String body) {
  try {
    final json = jsonDecode(body);
    return json is Map<String, dynamic> && json['title'] is String ? json['title'] as String : null;
  } on FormatException {
    return null;
  }
}

/// The planner's own words for a refusal it answered with [status], from its problem body [problem].
String plannerWords(int status, Map<String, dynamic> problem) {
  final detail = problem['detail'] ?? problem['title'];
  return detail is String ? detail : 'the planner answered $status';
}

/// The faults a planner's problem body names, each starting with the field it names; none where it names none.
List<String> faultsIn(Map<String, dynamic> problem) {
  final parameters = problem['parameters'];
  return parameters is Map<String, dynamic> && parameters['faults'] is List<dynamic>
      ? [
          for (final fault in parameters['faults'] as List<dynamic>)
            if (fault is String) fault,
        ]
      : const <String>[];
}
