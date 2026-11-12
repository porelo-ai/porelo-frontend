// Linux only: it reads the planner's runtime directory with its POSIX modes, as planner_test.dart does.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/planner_log_level.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
import 'package:porelo_planning/porelo_planning.dart';

/// A stand-in planner on the loopback address: its log level, as the planner's `/log/level` keeps it.
class _Planner {
  _Planner._(this.server) {
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      final response = request.response;
      if (request.uri.path == '/log/level') {
        calls.add((request.method, request.headers.value(HttpHeaders.authorizationHeader), body));
        if (answer case (final status, final text)) {
          response.statusCode = status;
          response.write(text);
        } else {
          if (request.method == 'PUT') level = (jsonDecode(body) as Map<String, dynamic>)['level'] as String;
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({'level': keeps ?? level}));
        }
      } else {
        response.statusCode = HttpStatus.noContent;
      }
      await response.close();
    });
  }

  static Future<_Planner> start() async => _Planner._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;

  /// Each call of `/log/level`: its method, its Authorization header and its body.
  final calls = <(String, String?, String)>[];

  /// The level in force.
  String level = 'INFO';

  /// A level the planner keeps whatever it is told, where it keeps one.
  String? keeps;

  /// A status and body it answers instead, where it is set.
  (int, String)? answer;

  /// Writes the address file as the planner does: owner-only, in an owner-only directory.
  Future<void> announce(String runtime) async {
    final directory = await Directory('$runtime/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    final written = File('${directory.path}/planner.json.new');
    await written.writeAsString(jsonEncode({'port': server.port, 'token': 'token-of-the-test'}));
    await Process.run('chmod', ['600', written.path]);
    await written.rename('${directory.path}/planner.json');
  }
}

void main() {
  late Directory runtime;
  late _Planner planner;

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-level-');
    await Process.run('chmod', ['700', runtime.path]);
    planner = await _Planner.start();
    await planner.announce(runtime.path);
  });

  tearDown(() async {
    await planner.server.close(force: true);
    await runtime.delete(recursive: true);
  });

  group('the planner is told a level', () {
    // Harm: the planner's log stays at its own level whatever the person chose, or the token goes elsewhere.
    test('as PUT /log/level with the token, and the level in force comes back', () async {
      final answered = await tellPlannerLevel(LogLevel.debug, runtimeDirectory: runtime.path);

      expect(answered, LogLevel.debug);
      expect(planner.calls.single, ('PUT', 'Bearer token-of-the-test', jsonEncode({'level': 'DEBUG'})));
    });

    // Harm: a planner older than the level's setting reads as a failure nobody can explain.
    test('a planner without it is said to need a newer planner', () async {
      planner.answer = (404, '');

      await expectLater(
        tellPlannerLevel(LogLevel.warn, runtimeDirectory: runtime.path),
        throwsA(isA<PlannerLevelRefused>().having((refusal) => refusal.words, 'words', contains('newer planner'))),
      );
    });

    // Harm: the planner's refusal is lost, and the person cannot tell why its log did not follow.
    test('a refusal is said in the planner\'s own words', () async {
      planner.answer = (400, jsonEncode({'title': 'InvalidLevel', 'detail': 'The level is none of the four.'}));

      await expectLater(
        tellPlannerLevel(LogLevel.warn, runtimeDirectory: runtime.path),
        throwsA(
          isA<PlannerLevelRefused>().having((refusal) => refusal.words, 'words', 'The level is none of the four.'),
        ),
      );
    });
  });

  group('the window\'s planner', () {
    late ValueNotifier<LogLevel> level;
    late LocalPlanner local;

    setUp(() {
      level = ValueNotifier<LogLevel>(LogLevel.warn);
      local = LocalPlanner(
        projects: () => ['demo'],
        repositories: (project) => PlannerProject('https://example.org/$project.git'),
        runtimeDirectory: runtime.path,
        candidates: const [],
        start: (_, _) async => fail('no planner may be started'),
        logLevel: level,
      );
    });

    tearDown(() {
      local.dispose();
      level.dispose();
    });

    Future<void> answered() async {
      for (var i = 0; i < 100 && planner.calls.length + (local.levelProblem == null ? 0 : 1) < 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // Harm: a planner found after the window started logs at its own level, not the one the person chose.
    test('a planner found is told the chosen level, and a change is told at once', () async {
      await local.reach();
      await answered();
      expect(planner.calls.map((call) => call.$3), [
        jsonEncode({'level': 'WARN'}),
      ]);
      expect(local.plannerLevel, LogLevel.warn);

      planner.calls.clear();
      level.value = LogLevel.debug;
      await answered();
      expect(planner.calls.map((call) => call.$3), [
        jsonEncode({'level': 'DEBUG'}),
      ]);
      expect(local.plannerLevel, LogLevel.debug);
      expect(local.levelProblem, isNull);
    });

    // Harm: the person believes both logs follow the choice while the planner's does not.
    test('a planner that keeps another level, or refuses, is kept as such', () async {
      planner.keeps = 'ERROR';
      await local.reach();
      await answered();
      expect(local.plannerLevel, LogLevel.error);

      planner.answer = (404, '');
      level.value = LogLevel.info;
      // The first call is still counted, so this waits for the refusal itself, which a loaded machine reads late.
      for (var i = 0; i < 500 && local.levelProblem == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(local.plannerLevel, isNull);
      expect(local.levelProblem, contains('newer planner'));
    });
  });

  // Harm: a slow answer to an earlier level arrives last, and the window says the planner is at a level no longer chosen.
  test('an answer overtaken by a later level is dropped', () async {
    final level = ValueNotifier<LogLevel>(LogLevel.info);
    final answers = <LogLevel, Completer<LogLevel>>{};
    final local = LocalPlanner(
      projects: () => ['demo'],
      repositories: (project) => PlannerProject('https://example.org/$project.git'),
      runtimeDirectory: runtime.path,
      candidates: const [],
      start: (_, _) async => fail('no planner may be started'),
      logLevel: level,
      tellLevel: (wanted, {runtimeDirectory}) => (answers[wanted] = Completer<LogLevel>()).future,
    );
    addTearDown(() {
      local.dispose();
      level.dispose();
    });
    await local.reach();
    level.value = LogLevel.debug;
    await Future<void>.delayed(Duration.zero);

    answers[LogLevel.debug]!.complete(LogLevel.debug);
    await Future<void>.delayed(Duration.zero);
    answers[LogLevel.info]!.complete(LogLevel.info);
    await Future<void>.delayed(Duration.zero);

    expect(local.plannerLevel, LogLevel.debug);
  });
}
