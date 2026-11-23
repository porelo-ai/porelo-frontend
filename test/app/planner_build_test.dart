// Linux only: it reads the planner's runtime directory with its POSIX modes, as planner_test.dart does.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_frontend/src/app/planner_build.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/signed_planner.dart';

const _commit = '0123456789abcdef0123456789abcdef01234567';

/// A stand-in planner on the loopback address that proves and checks its token as the planner does, answering
/// `/health` with [answer].
class _Planner {
  _Planner._(this.server) {
    server.listen(
      (request) => signing.serve(
        request,
        (method, path, body) async => path == '/health' ? answer : (HttpStatus.notFound, '{}'),
      ),
    );
  }

  static Future<_Planner> start() async => _Planner._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;

  /// How it proves the token and checks each request's signature, and the requests it took.
  final signing = SignedPlanner('token-of-the-test');

  /// The status and body `/health` answers.
  (int, String) answer = (200, jsonEncode({'status': 'UP'}));

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
    runtime = await Directory.systemTemp.createTemp('planner-build-');
    await Process.run('chmod', ['700', runtime.path]);
    planner = await _Planner.start();
    await planner.announce(runtime.path);
  });

  tearDown(() async {
    await planner.server.close(force: true);
    await runtime.delete(recursive: true);
  });

  Future<PlannerBuild?> ask() => askPlannerBuild(runtimeDirectory: runtime.path);

  // Harm: nothing in the window tells which planner build answers the planning, or About hands the planner's token to
  // whatever listens on the port its address file names.
  group('the planner\'s health names its build', () {
    test('its version and commit, asked as GET /health signed, the token never sent', () async {
      planner.answer = (200, jsonEncode({'status': 'UP', 'version': '0.2.0~snapshot.41', 'commit': _commit}));

      expect(await ask(), const PlannerBuild(version: '0.2.0~snapshot.41', commit: _commit));
      expect(planner.signing.requests.single, ('GET', '/health', null), reason: 'no Authorization header');
    });

    test('its version alone where its commit is no full commit', () async {
      planner.answer = (200, jsonEncode({'status': 'UP', 'version': '0.2.0', 'commit': 'abc'}));

      expect(await ask(), const PlannerBuild(version: '0.2.0'));
    });

    test('its version alone where its build had no checkout', () async {
      planner.answer = (200, jsonEncode({'status': 'UP', 'version': '0.2.0', 'commit': null}));

      expect(await ask(), const PlannerBuild(version: '0.2.0'));
    });
  });

  // Harm: an older planner, or one answering something else, reads as a planner not reached, or shows text it sent.
  group('a planner reached that names no build reads as one naming no version', () {
    for (final (what, body) in [
      ('an older answer, status alone', jsonEncode({'status': 'UP'})),
      ('a version of the wrong type', jsonEncode({'status': 'UP', 'version': 2, 'commit': _commit})),
      ('a version that is no version', jsonEncode({'status': 'UP', 'version': '0.2.0\n\u001b[2J', 'commit': null})),
      ('a version ending in a line break', jsonEncode({'status': 'UP', 'version': '0.2.0\n', 'commit': null})),
      ('a version of endless digits', jsonEncode({'status': 'UP', 'version': '0.2.${'9' * 40}', 'commit': null})),
      ('no JSON', 'UP'),
    ]) {
      test(what, () async {
        planner.answer = (200, body);

        expect(await ask(), const PlannerBuild());
      });
    }

    test('an answer other than 200', () async {
      planner.answer = (503, jsonEncode({'title': 'Service Unavailable'}));

      expect(await ask(), const PlannerBuild());
    });
  });

  // Harm: an answer without end is read whole into the window.
  test('an answer past 64 KiB names no version', () async {
    planner.answer = (200, jsonEncode({'status': 'UP', 'version': '0.2.0', 'padding': 'x' * (64 * 1024)}));

    expect(await ask(), const PlannerBuild());
  });

  // Harm: a window with no planner's address reads as one whose planner names no version.
  test('no address file answers none', () async {
    await File('${runtime.path}/porelo-planner/planner.json').delete();

    expect(await ask(), isNull);
  });

  // Harm: a planner that is not there reads as one that names no version.
  test('no planner reached answers none', () async {
    await planner.server.close(force: true);

    expect(await ask(), isNull);
  });

  // Harm: a listener that cannot prove the planner's token is taken for the planner, and its words shown in About.
  test('a listener that cannot prove the token is no planner reached, and is never asked', () async {
    planner.signing.stranger = true;
    planner.answer = (200, jsonEncode({'status': 'UP', 'version': '9.9.9', 'commit': _commit}));

    expect(await ask(), isNull);
    expect(planner.signing.requests, isEmpty, reason: 'nothing is sent to a listener that failed the proof');
  });

  // Harm: About says a planner answers while the window has reached none, or names a build it never asked.
  group('the window\'s planner', () {
    LocalPlanner local({required AskPlannerBuild askBuild}) {
      final made = LocalPlanner(
        projects: () => ['demo'],
        repositories: (project) => PlannerProject('https://example.org/$project.git'),
        runtimeDirectory: runtime.path,
        candidates: const [],
        start: (_, _) async => fail('no planner may be started'),
        askBuild: askBuild,
      );
      addTearDown(made.dispose);
      return made;
    }

    test('answers none before it reached a planner, without asking', () async {
      final planner = local(askBuild: ({runtimeDirectory}) async => fail('no planner may be asked'));

      expect(await planner.build(), isNull);
    });

    // Harm: a fault in reading the planner's build reads as a planner not reached, and nothing says why.
    test('a failed ask answers none and says why in the window\'s log', () async {
      final logs = await Directory.systemTemp.createTemp('planner-build-logs-');
      final before = windowLog;
      windowLog = WindowLog(logs.path, level: ValueNotifier(LogLevel.debug), keepPrivate: (_) async {});
      addTearDown(() async {
        windowLog = before;
        await logs.delete(recursive: true);
      });
      final planner = local(askBuild: ({runtimeDirectory}) async => throw StateError('a fault of the reader'));
      await planner.reach();

      expect(await planner.build(), isNull);
      final log = File('${logs.path}/${WindowLog.fileName}');
      expect(log.existsSync() ? log.readAsStringSync() : '', contains('a fault of the reader'));
    });

    test('asks the planner it reached, under its own runtime directory', () async {
      final asked = <String?>[];
      final planner = local(
        askBuild: ({runtimeDirectory}) async {
          asked.add(runtimeDirectory);
          return const PlannerBuild(version: '0.2.0');
        },
      );
      await planner.reach();

      expect(await planner.build(), const PlannerBuild(version: '0.2.0'));
      expect(asked, [runtime.path]);
    });
  });
}
