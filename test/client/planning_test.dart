@Tags(['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

void main() {
  // Harm: omitted fields manufacture low priority, stopped work, or completed progress.
  test('missing and unknown planning fields remain unsaid', () {
    final story = PlanStory.from({});
    expect(story.id, isEmpty);
    expect(story.state, isEmpty);
    expect(story.priority, isEmpty);
    expect(story.work, isNull);
    expect(story.issuesReported, isFalse);
    expect(story.completedIssues, isNull);
    expect(PlanWork.from({}).atWork, isNull);
    expect(
      PlanStory.from({
        'issues': [
          {'id': 'A'},
        ],
      }).completedIssues,
      isNull,
    );
    expect(PlanState.from({'kind': 'LATER'}).kind, 'LATER');
    expect(PlanStory.from({'priority': 'Urgent'}).priority, 'Urgent');
    expect(PlanStory.from({'issues': <Map<String, dynamic>>[]}).completedIssues, 0);
    expect(PlanWork.from({'atWork': false}).atWork, isFalse);
    final snapshot = PlanningSnapshot.from({'states': 'wrong', 'phases': null, 'stories': false});
    expect(snapshot.complete, isFalse);
    expect(snapshot.states, isEmpty);
    expect(snapshot.stories, isEmpty);
  });

  // Harm: missing or malformed reading metadata becomes an invented round or a false stop signal.
  test('reading metadata preserves reported values and keeps absent fields unsaid', () {
    final absent = PlanIssue.from({});
    expect(absent.rounds, isNull);
    expect(absent.roundsMost, isNull);
    expect(absent.readingStopped, isNull);
    final malformed = PlanIssue.from({'rounds': '2', 'roundsMost': 4.5, 'readingStopped': 'false'});
    expect(malformed.rounds, isNull);
    expect(malformed.roundsMost, isNull);
    expect(malformed.readingStopped, isNull);
    final reported = PlanIssue.from({'rounds': 2, 'roundsMost': 5, 'readingStopped': true});
    expect(reported.rounds, 2);
    expect(reported.roundsMost, 5);
    expect(reported.readingStopped, isTrue);
    final zero = PlanIssue.from({'rounds': 0, 'roundsMost': 0, 'readingStopped': false});
    expect(zero.rounds, 0);
    expect(zero.roundsMost, 0);
    expect(zero.readingStopped, isFalse);
  });

  group('planning over varlink', () {
    late MockDaemon daemon;
    late PoreloClient client;
    setUp(() async {
      daemon = MockDaemon();
      await daemon.start();
      client = await PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'planning mock'));
    });
    tearDown(() => daemon.stop());

    // Harm: the wrong method or project reaches the daemon without a visible refusal.
    test('workflow and stories use the agreed project parameter and retain revisions', () async {
      daemon.method('GetPlanningWorkflow', (parameters) {
        expect(parameters, {'project': 'demo'});
        return {
          'states': [
            {'name': 'Investigating', 'kind': 'WORKING', 'done': 'Ready'},
          ],
          'phases': [
            {
              'name': 'Analysis',
              'states': ['Investigating'],
            },
          ],
        };
      });
      daemon.method('ListStories', (parameters) {
        expect(parameters, {'project': 'demo'});
        return {
          'stories': [
            {'id': 'S1', 'state': 'Investigating', 'priority': 'Urgent'},
          ],
          'revision': 'r7',
        };
      });
      final workflow = await client.planningWorkflow('demo');
      expect(workflow.states.single.done, 'Ready');
      expect(workflow.phases.single.states, ['Investigating']);
      final stories = await client.stories('demo');
      expect(stories.stories.single.state, 'Investigating');
      expect(stories.stories.single.priority, 'Urgent');
      expect(stories.revision, 'r7');
    });

    // Harm: the board misses the initial answer or applies another project's changes.
    test('the watch immediately answers and pushes replacements only for its project', () async {
      final first = Completer<PlanningSnapshot>(), changed = Completer<PlanningSnapshot>();
      final seen = <PlanningSnapshot>[];
      final watch = client.watchStories('demo').listen((board) {
        seen.add(board);
        if (seen.length == 1) first.complete(board);
        if (seen.length == 2) changed.complete(board);
      });
      final initial = await first.future.timeout(const Duration(seconds: 5));
      expect(initial.stories, hasLength(34));
      daemon.pushPlanning('other', {
        'states': <Map<String, dynamic>>[],
        'phases': <Map<String, dynamic>>[],
        'stories': <Map<String, dynamic>>[],
        'revision': 'wrong',
      });
      daemon.pushPlanning('demo', {
        'states': <Map<String, dynamic>>[],
        'phases': <Map<String, dynamic>>[],
        'stories': <Map<String, dynamic>>[],
        'revision': 'new',
      });
      expect((await changed.future.timeout(const Duration(seconds: 5))).revision, 'new');
      expect(seen.map((board) => board.revision), ['design-1', 'new']);
      await watch.cancel().timeout(const Duration(seconds: 5));
    });

    // Harm: leaving a board hangs while its daemon holds the stream open without changes.
    test('canceling a silent planning watch closes its own connection', () async {
      final entered = Completer<void>();
      final silence = StreamController<Map<String, dynamic>>();
      daemon.pushes('WatchStories', (_) {
        entered.complete();
        return silence.stream;
      });
      final watching = client.watchStories('demo').listen((_) {});
      await entered.future.timeout(const Duration(seconds: 5));
      expect(daemon.openConnections, 1);
      await watching.cancel().timeout(const Duration(seconds: 5));
      for (var attempts = 0; attempts < 100 && daemon.openConnections != 0; attempts++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(daemon.openConnections, 0);
      await silence.close();
    });

    // Harm: one missing additive feature makes the entire machine unusable.
    test('each missing planning method becomes feature unsupported', () async {
      daemon.remove('GetPlanningWorkflow');
      daemon.remove('ListStories');
      daemon.remove('WatchStories');
      await expectLater(client.planningWorkflow('demo'), throwsA(isA<FeatureNotSupported>()));
      await expectLater(client.stories('demo'), throwsA(isA<FeatureNotSupported>()));
      await expectLater(client.watchStories('demo'), emitsError(isA<FeatureNotSupported>()));
    });

    // Harm: a daemon refusal is swallowed and rendered as an empty board.
    test('a refused watch retains the daemon error and parameters', () async {
      daemon.fails('WatchStories', 'org.fuin.porelo.Tasks1.PlanningRefused', {'detail': 'cannot read the store'});
      await expectLater(
        client.watchStories('demo'),
        emitsError(
          isA<VarlinkException>().having((error) => error.parameters['detail'], 'detail', 'cannot read the store'),
        ),
      );
    });
  });
}
