import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_planning/porelo_planning.dart' show PlannerAddress;

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
/// Only to the loopback address the address file names, with its token, never through a proxy; an answer is waited
/// for [within].
Future<LogLevel> tellPlannerLevel(
  LogLevel level, {
  String? runtimeDirectory,
  Duration within = const Duration(seconds: 10),
}) async {
  final address = await PlannerAddress.read(runtimeDirectory: runtimeDirectory);
  final client = HttpClient()
    ..connectionTimeout = within
    ..autoUncompress = false
    ..findProxy = ((_) => 'DIRECT');
  try {
    final request = await client.putUrl(address.base.replace(path: '/log/level')).timeout(within);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer ${address.token}')
      ..contentType = ContentType.json;
    request.write(jsonEncode({'level': level.word}));
    final response = await request.close().timeout(within);
    final body = await utf8.decodeStream(response.take(64 * 1024)).timeout(within);
    return plannerLevelAnswered(response.statusCode, body);
  } on TimeoutException {
    throw PlannerLevelRefused('the planner did not answer within ${within.inSeconds} s');
  } on SocketException catch (error) {
    throw PlannerLevelRefused('the planner could not be reached: ${error.message}');
  } finally {
    client.close(force: true);
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
