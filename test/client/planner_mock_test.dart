// Linux only: porelo-planner is built for Linux, and its mock mode is started in a runtime directory set to mode
// 700 with chmod.
@Tags(<String>['linux'])
library;

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

  // Harm: a card or an issue row opens nothing, another item, or an item stripped of what its screen shows, when the
  // window's planner is what serves the board.
  test('a story and one of its issues are read alone through the window\'s planner, with their details', () async {
    final source = window.providers.single.source;

    // ST291 and B541 as the planner's mock board holds them.
    final read = await source.getStory('demo', 'ST291');
    final issues = await source.listStoryIssues('demo', 'ST291');
    final issue = await source.getIssue('demo', 'B541');

    expect(read.revision, isNotEmpty);
    expect(read.story?.id, 'ST291');
    expect(read.story?.title, 'The host run by a program of its own, built like porelo');
    expect(read.story?.priority, 'Highest');
    expect(read.story?.description, startsWith('# The host tool'));
    expect(read.story?.link, 'https://example.org/stories/ST291');

    expect(issues.reported, isTrue, reason: 'the planner lists the story\'s issues in full');
    final row = issues.issues.singleWhere((each) => each.id == 'B541');
    expect(row.state, 'Implementing');
    expect(row.link, 'https://example.org/issues/B541');

    final detail = issue.issue;
    expect(detail?.id, 'B541');
    expect(detail?.repository, 'porelo');
    expect(detail?.title, 'The host tool reads the organization and a task by its signature');
    expect(detail?.state, 'Implementing');
    expect(detail?.size, 'L');
    expect(detail?.blockedBy, ['B540']);
    expect(detail?.link, 'https://example.org/issues/B541');
    expect(issue.criteriaReported, isTrue);
    expect(issue.whatMustBeTrue, ['The work meets the story description.']);
    // No story is asserted: the planner's issue read names none, and the screen finds the issue's story on the board,
    // where ST291 lists B541.
    expect(issues.issues.map((each) => each.id), contains('B541'));
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
