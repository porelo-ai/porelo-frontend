// Linux only: it reads the planner's runtime directory with its POSIX modes, as planner_test.dart does.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner_stage_results.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlannerProject;

import '../support/signed_planner.dart';

/// The token the stand-in planner writes into its address file.
const _token = 'token-of-the-test';

/// A stand-in planner on the loopback address that proves and checks the token as the planner does: what
/// `POST /projects/{project}/tasks/{task}/result` was sent, and what it answers.
class _Planner {
  _Planner._(this.server) {
    server.listen(
      (request) => signing.serve(request, (method, path, body) async {
        calls.add((method, path, body));
        if (method == 'PUT') given.add(path);
        return method == 'PUT'
            ? (204, '')
            : given.isEmpty && unknownUntilGiven
            ? (404, jsonEncode({'title': 'NoSuchProject', 'detail': 'The planner was not given project demo'}))
            : answer;
      }),
    );
  }

  static Future<_Planner> start() async => _Planner._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;

  /// How it proves the token and checks each request's signature.
  final signing = SignedPlanner(_token);

  /// Each call it took, signed: its method, its path and its body.
  final calls = <(String, String, String)>[];

  /// The projects it was given, by path.
  final given = <String>[];

  /// Whether it knows no project until it is given one, as after its start.
  bool unknownUntilGiven = false;

  /// The status and body it answers.
  (int, String) answer = (200, '');

  /// Writes the address file as the planner does: owner-only, in an owner-only directory.
  Future<void> announce(String runtime) async {
    final directory = await Directory('$runtime/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    final written = File('${directory.path}/planner.json.new');
    await written.writeAsString(jsonEncode({'port': server.port, 'token': _token}));
    await Process.run('chmod', ['600', written.path]);
    await written.rename('${directory.path}/planner.json');
  }
}

void main() {
  const offer = '00000000-0000-4000-8000-00000000a7a1';
  const result = <String, Object?>{
    'format': 'porelo-stage-result-1',
    'kind': 'ANALYSIS',
    'issues': [
      {'id': 'PI68', 'plan': 'Read the docs against the code.', 'size': 'S', 'sizeWhy': 'One module.'},
    ],
  };
  late Directory runtime;
  late _Planner planner;

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-stage-results-');
    await Process.run('chmod', ['700', runtime.path]);
    planner = await _Planner.start();
    await planner.announce(runtime.path);
  });

  tearDown(() async {
    await planner.server.close(force: true);
    await runtime.delete(recursive: true);
  });

  // Harm: a stage's result reaches no planner, reaches it changed or without its offer, or under another task.
  test('a result goes signed as POST /projects/{project}/tasks/{task}/result with its offer, unchanged', () async {
    await handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path);

    final (method, path, body) = planner.calls.single;
    expect((method, path), ('POST', '/projects/demo/tasks/pi/result'));
    expect(jsonDecode(body), {'offer': offer, 'result': result});
  });

  // Harm: a stage that left no result is never said to the planner, so its issue waits for ever, or is moved on.
  test('a stage with no result says why, with its offer and nothing else', () async {
    await handStageResult('demo', 'pi', offer, missing: 'it wrote no analysis.json', runtimeDirectory: runtime.path);

    expect(jsonDecode(planner.calls.single.$3), {'offer': offer, 'missing': 'it wrote no analysis.json'});
  });

  // Harm: a result handed in after the planner restarted is refused for a project it was not given, and is lost.
  test('a planner not given the project is given it with its repository, and asked once more', () async {
    planner.unknownUntilGiven = true;

    await handStageResult(
      'demo',
      'pi',
      offer,
      result: result,
      runtimeDirectory: runtime.path,
      projects: (project) => PlannerProject('https://example.org/$project.git'),
    );

    expect(planner.calls.map((call) => (call.$1, call.$2)), [
      ('POST', '/projects/demo/tasks/pi/result'),
      ('PUT', '/projects/demo'),
      ('POST', '/projects/demo/tasks/pi/result'),
    ]);
  });

  // Harm: a refused result reads as saved, so the board says nothing, or its faults are lost.
  test('a refused result names the planner\'s faults and is no failure to try again', () async {
    planner.answer = (
      422,
      jsonEncode({
        'title': 'ResultRefused',
        'detail': 'The analysis is not saved.',
        'parameters': {
          'faults': ['issues[0].size: not one of XS, S, M, L, XL'],
        },
      }),
    );

    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(
        isA<StageResultNotSaved>()
            .having((refusal) => refusal.words, 'words', 'The analysis is not saved.')
            .having((refusal) => refusal.faults, 'faults', ['issues[0].size: not one of XS, S, M, L, XL'])
            .having((refusal) => refusal.transient, 'transient', isFalse),
      ),
    );
  });

  // Harm: a result the planner could not save now is dropped instead of handed in again; an older planner's 404 is
  // taken for a refusal of the result itself.
  test('a planner that cannot save now is tried again; an older planner is said to need a newer one', () async {
    planner.answer = (503, jsonEncode({'title': 'StoreBusy', 'detail': 'The store is busy.'}));
    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(isA<StageResultNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );

    planner.answer = (404, jsonEncode({'title': 'NotFound'}));
    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(
        isA<StageResultNotSaved>()
            .having((refusal) => refusal.words, 'words', contains('newer planner'))
            .having((refusal) => refusal.transient, 'transient', isFalse),
      ),
    );
  });

  // Harm: a planner that cannot prove the token, as a stale address file or a planner starting again, is taken for
  // one that refused the result: the end goes on and a good result is lost.
  test('a planner not proven has not refused: the result is handed in again later', () async {
    planner.signing.stranger = true;

    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(isA<StageResultNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );
    expect(planner.calls, isEmpty);
  });

  // Harm: a project the planner was given but does not know yet, while it settles, ends the hand-in for good.
  test('a project still unknown after it was given is tried again later', () async {
    planner.answer = (404, jsonEncode({'title': 'NoSuchProject'}));

    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(isA<StageResultNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );
  });

  // Harm: a planner not running loses the result instead of having it handed in once it runs.
  test('no planner running is a failure to try again later', () async {
    await File('${runtime.path}/porelo-planner/planner.json').delete();

    await expectLater(
      handStageResult('demo', 'pi', offer, result: result, runtimeDirectory: runtime.path),
      throwsA(isA<StageResultNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );
  });
}
