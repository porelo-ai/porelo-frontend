import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner.dart';
import 'package:porelo_planning/porelo_planning.dart';

/// The window against porelo-planner's mock mode, in a runtime directory of the test's own, never the person's.
void main() {
  final planner = plannerCandidates(Platform.environment).where((each) => File(each).existsSync()).firstOrNull;
  final skip = planner == null
      ? 'porelo-planner is neither at $plannerInstalled nor on the path, so its mock mode cannot be started'
      : null;

  late Directory runtime;
  late LocalPlanner window;
  final started = <Process>[];
  var repository = 'https://example.org/demo.git';

  Future<void> reset() async {
    final address = jsonDecode(File('${runtime.path}/porelo-planner/planner.json').readAsStringSync()) as Map;
    final client = HttpClient();
    try {
      final request = await client.post('127.0.0.1', address['port'] as int, '/mock/reset');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${address['token']}');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.noContent, reason: 'the mock resets its board between cases');
    } finally {
      client.close(force: true);
    }
  }

  setUpAll(() async {
    if (planner == null) return;
    // Under the system's temporary directory, so the mock never meets the person's own runtime directory.
    runtime = await Directory.systemTemp.createTemp('planner-e2e-');
    // As the system makes a runtime directory: the planner refuses one others may read.
    await Process.run('chmod', ['700', runtime.path]);
    window = LocalPlanner(
      projects: () => ['demo'],
      repositories: (_) => PlannerProject(repository),
      runtimeDirectory: runtime.path,
      candidates: [planner],
      // The mock mode, and a process the test can stop: the window's own start leaves its planner running. Every start
      // is kept, so a second one is counted and stopped too; its output is drained so it never blocks on a full pipe.
      start: (executable, environment) async {
        final process = await Process.start(executable, ['--mock'], environment: environment);
        started.add(process);
        process.stdout.drain<void>().ignore();
        process.stderr.drain<void>().ignore();
      },
      wait: const Duration(seconds: 60),
    );
    await window.reach();
    expect(window.notReached, isNull, reason: 'the started mock wrote its address');
  });

  tearDownAll(() async {
    if (planner == null) return;
    window.dispose();
    for (final process in started) {
      process.kill();
      await process.exitCode;
    }
    await runtime.delete(recursive: true);
  });

  setUp(() async {
    if (planner == null) return;
    repository = 'https://example.org/demo.git';
    await reset();
  });

  // Harm: the window's planning place shows nothing, or something other than the planner's board, from a planner it
  // started itself.
  test('the window starts the planner once and reads the mock board through it', () async {
    final snapshot = await window.providers.single.source.stories('demo');

    expect(started, hasLength(1), reason: 'one window starts one planner');
    expect(snapshot.stories, isNotEmpty);
  }, skip: skip);

  // Harm: a refusal of the planner's is lost, turned into an empty board, or shown by its name alone.
  test('the planner refuses a project whose repository is a local path, and the refusal keeps its words', () async {
    repository = '/srv/git/demo';

    await expectLater(
      window.providers.single.source.stories('demo'),
      throwsA(
        isA<PlanningRefusal>()
            .having((refusal) => refusal.name, 'name', 'NotACloneUrl')
            .having((refusal) => refusal.description.trim(), 'words', isNotEmpty),
      ),
    );
  }, skip: skip);
}
