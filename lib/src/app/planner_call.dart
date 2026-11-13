import 'package:porelo_planning/porelo_planning.dart' show PlannerAnswer, PlannerNotProven, callPlanner;

import 'window_log.dart';

/// Calls this account's planner once, as the window's own calls do, through the planning package's [callPlanner]: it
/// reads the address file under [runtimeDirectory], has the listener on its port prove the token, signs the request
/// and checks the answer's proof, so the token itself is never sent.
///
/// A listener that is not this account's planner ([PlannerNotProven]) is written to the window's log - why, its port
/// and the package's line for it, never the token - and the call fails with it; any other refusal of the package is
/// thrown as it is.
Future<PlannerAnswer> callOwnPlanner(
  String method,
  List<String> segments, {
  Map<String, Object?>? json,
  String? runtimeDirectory,
  required Duration within,
  required int maxBody,
}) async {
  try {
    return await callPlanner(
      method,
      segments,
      json: json,
      runtimeDirectory: runtimeDirectory,
      timeout: within,
      maxBody: maxBody,
    );
  } on PlannerNotProven catch (notProven) {
    windowLog.warn(
      'porelo-planner is not trusted (${notProven.failure.name}, port ${notProven.port}): ${notProven.logLine}.',
    );
    rethrow;
  }
}
