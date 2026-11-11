import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_planning/porelo_planning.dart' show PlannerAddress, PlannerProject, PlannerProjects;

/// Hands the [idea] a discussion of [offer] wrote in [project] to the planner of this account, and answers the id of
/// the story it was saved as.
typedef HandIdea = Future<String> Function(
  String project,
  String offer,
  Map<String, Object?> idea, {
  String? runtimeDirectory,
  PlannerProjects? projects,
});

/// Why the planner did not save an idea, in words: its own where it gave some.
class IdeaNotSaved implements Exception {
  /// Takes the words, the faults the planner named, and whether trying again later may save it.
  const IdeaNotSaved(this.words, {this.faults = const [], this.transient = false});

  /// What went wrong, for a person.
  final String words;

  /// The faults the planner named in the idea, each starting with the field it names.
  final List<String> faults;

  /// Whether the planner could not be asked, or could not save it now, so a later try may save it.
  final bool transient;

  @override
  String toString() => faults.isEmpty ? words : '$words ${faults.join('; ')}';
}

/// The most bytes a hand-in's body may have.
const mostIdeaBytes = 65536;

/// The planner's `POST /projects/{project}/ideas`, at the address its `planner.json` under [runtimeDirectory] names:
/// the body `{"offer": ..., "idea": ...}`, answered with the id of the story saved.
///
/// A planner that was not given [project] since it started (`NoSuchProject`) is given it, with the repository
/// [projects] names, as `PUT /projects/{project}`, and is asked once more, as the board's reads do.
///
/// Only to the loopback address the address file names, with its token, never through a proxy; an answer is waited
/// for [within].
Future<String> handIdea(
  String project,
  String offer,
  Map<String, Object?> idea, {
  String? runtimeDirectory,
  PlannerProjects? projects,
  Duration within = const Duration(seconds: 30),
}) async {
  final body = utf8.encode(jsonEncode({'offer': offer, 'idea': idea}));
  if (body.length > mostIdeaBytes) {
    throw const IdeaNotSaved('the idea is larger than the planner takes (64 KiB)');
  }
  final PlannerAddress address;
  try {
    address = await PlannerAddress.read(runtimeDirectory: runtimeDirectory);
  } on Object {
    throw const IdeaNotSaved('no planner is running for this account', transient: true);
  }
  final client = HttpClient()
    ..connectionTimeout = within
    ..autoUncompress = false
    ..findProxy = ((_) => 'DIRECT');
  Future<(int, String)> send(String method, List<String> path, List<int> body) async {
    final request = await client.openUrl(method, address.base.replace(pathSegments: path)).timeout(within);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer ${address.token}')
      ..contentType = ContentType.json
      ..contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(within);
    return (response.statusCode, await utf8.decodeStream(response.take(256 * 1024)).timeout(within));
  }

  try {
    final ideas = ['projects', project, 'ideas'];
    var (status, answer) = await send('POST', ideas, body);
    if (projects != null && status == 404 && _title(answer) == 'NoSuchProject') {
      final PlannerProject given;
      try {
        given = await projects(project);
      } on Object {
        throw IdeaNotSaved('no watched machine names the repository of $project yet', transient: true);
      }
      final told = await send('PUT', [
        'projects',
        project,
      ], utf8.encode(jsonEncode({'repository': given.repository, 'branch': ?given.branch})));
      if (told.$1 < 200 || told.$1 > 299) return ideaAnswered(told.$1, told.$2);
      (status, answer) = await send('POST', ideas, body);
    }
    return ideaAnswered(status, answer);
  } on TimeoutException {
    throw IdeaNotSaved('the planner did not answer within ${within.inSeconds} s', transient: true);
  } on SocketException catch (error) {
    throw IdeaNotSaved('the planner could not be reached: ${error.message}', transient: true);
  } finally {
    client.close(force: true);
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

/// The story id the planner answered with [status] and [body]: a refusal in the planner's words with the faults it
/// named, a planner that does not take ideas yet said as such, and a planner that cannot save now marked transient.
String ideaAnswered(int status, String body) {
  Object? json;
  try {
    json = body.isEmpty ? null : jsonDecode(body);
  } on FormatException {
    json = null;
  }
  final problem = json is Map<String, dynamic> ? json : const <String, dynamic>{};
  if (status == 201) {
    final id = problem['id'];
    if (id is String && id.isNotEmpty) return id;
    throw const IdeaNotSaved('the planner saved the idea but named no story');
  }
  if (status == 404 && problem['title'] != 'NoSuchProject') {
    throw const IdeaNotSaved('this planner cannot take ideas; it needs a newer planner');
  }
  final detail = problem['detail'] ?? problem['title'];
  final words = detail is String ? detail : 'the planner answered $status';
  final parameters = problem['parameters'];
  final faults = parameters is Map<String, dynamic> && parameters['faults'] is List<dynamic>
      ? [
          for (final fault in parameters['faults'] as List<dynamic>)
            if (fault is String) fault,
        ]
      : const <String>[];
  throw IdeaNotSaved(words, faults: faults, transient: status == 503 || status == 504);
}
