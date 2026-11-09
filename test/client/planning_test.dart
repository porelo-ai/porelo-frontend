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
    expect(story.priority, isNull);
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
            {'id': 'StoryOne', 'state': 'Investigating', 'priority': 'Urgent'},
          ],
          'revision': 'r7',
        };
      });
      final workflow = await client.planningWorkflow('demo');
      expect(workflow.states.single.name, 'Investigating');
      expect(workflow.phases.single.states, ['Investigating']);
      final stories = await client.stories('demo');
      expect(stories.stories.single.state, 'Investigating');
      expect(stories.stories.single.priority, 'Urgent');
      expect(stories.revision, 'r7');
    });

    // Harm: a move reaches the wrong project, loses its revision, or serializes the wrong fields.
    test('story and issue moves share one atomic call', () async {
      daemon.method('SaveMoves', (parameters) {
        expect(parameters, {
          'project': 'demo',
          'moves': [
            {'story': 'StoryOne', 'to': 'Review'},
            {'issue': 'IssueOne', 'to': 'Finished'},
          ],
          'revision': 'r1',
        });
        return {
          'revision': 'r2',
          'moved': ['IssueOne'],
        };
      });
      final result = await client.saveMoves('demo', [
        const PlanningStoryMove('StoryOne', 'Review'),
        const PlanningIssueMove('IssueOne', 'Finished'),
      ], 'r1');
      expect(result.revision, 'r2');
      expect(result.moved, ['IssueOne']);
    });

    // Harm: an atomic save loses a destination or omits daemon-reported issue states.
    test('an atomic story batch sends one revision and reads the complete move answer', () async {
      var calls = 0;
      daemon.method('SaveMoves', (parameters) {
        calls++;
        expect(parameters, {
          'project': 'demo',
          'moves': [
            {'story': 'StoryOne', 'to': 'Review'},
            {'story': 'StoryTwo', 'to': 'Finished'},
          ],
          'revision': 'initial',
        });
        return {
          'moved': ['IssueOne'],
          'revision': 'saved',
          'states': [
            {'name': 'Review', 'kind': 'WAITING'},
            {'name': 'Finished', 'kind': 'CLOSED'},
          ],
          'phases': [
            {
              'name': 'Work',
              'states': ['Review', 'Finished'],
            },
          ],
          'stories': [
            {
              'id': 'StoryOne',
              'state': 'Review',
              'issues': [
                {'id': 'IssueOne', 'state': 'Review'},
                {'id': 'IssueTwo', 'state': 'Finished'},
              ],
            },
            {'id': 'StoryTwo', 'state': 'Finished', 'issues': <Map<String, dynamic>>[]},
          ],
        };
      });
      final reply = await client.saveMoves('demo', [
        const PlanningStoryMove('StoryOne', 'Review'),
        const PlanningStoryMove('StoryTwo', 'Finished'),
      ], 'initial');
      expect(calls, 1);
      expect(reply.complete, isTrue);
      expect(reply.moved, ['IssueOne']);
      expect(reply.revision, 'saved');
      expect(reply.moved, ['IssueOne']);
    });

    // Harm: stale planning errors lose the daemon details before reaching the board.
    test('both move methods preserve stale revision details', () async {
      for (final method in ['SaveMoves', 'SaveMoves', 'SaveMoves']) {
        daemon.fails(method, 'org.fuin.porelo.Tasks1.StaleRevision', {'detail': 'The planning revision changed'});
      }
      final refused = throwsA(
        isA<VarlinkException>()
            .having((error) => error.name, 'name', 'org.fuin.porelo.Tasks1.StaleRevision')
            .having((error) => error.parameters['detail'], 'detail', 'The planning revision changed'),
      );
      await expectLater(client.saveMoves('demo', [const PlanningStoryMove('StoryOne', 'Review')], 'old'), refused);
      await expectLater(client.saveMoves('demo', [PlanningStoryMove('StoryOne', 'Review')], 'old'), refused);
      await expectLater(client.saveMoves('demo', [const PlanningIssueMove('IssueOne', 'Review')], 'old'), refused);
    });

    // Harm: detail reads send the wrong identifier or project and display a different item.
    test('standalone reads send exact project and identifier parameters', () async {
      daemon.method('GetStory', (parameters) {
        expect(parameters, {'project': 'demo', 'story': 'S2'});
        return {
          'story': {'id': 'S2', 'description': '# Story'},
          'revision': 'r2',
        };
      });
      daemon.method('ListStoryIssues', (parameters) {
        expect(parameters, {'project': 'demo', 'story': 'S2'});
        return {
          'issues': [
            {'id': 'I2', 'state': 'Reading'},
          ],
        };
      });
      daemon.method('GetIssue', (parameters) {
        expect(parameters, {'project': 'demo', 'issue': 'I2'});
        return {
          'issue': {
            'id': 'I2',
            'whatMustBeTrue': 'Confirmed work only',
            'findings': [
              {'number': 3, 'severity': 'BLOCKING', 'text': 'Check', 'line': 4},
            ],
            'subAgents': [
              {'name': 'Reader', 'brief': 'Read only'},
            ],
          },
          'revision': 'r2',
        };
      });
      final story = await client.getStory('demo', 'S2');
      expect(story.revision, 'r2');
      expect(story.story!.description, '# Story');
      final issues = await client.listStoryIssues('demo', 'S2');
      expect(issues.reported, isTrue);
      expect(issues.issues.single.id, 'I2');
      final issue = await client.getIssue('demo', 'I2');
      expect(issue.whatMustBeTrue, ['Confirmed work only']);
      expect(issue.findings.single.number, 3);
      expect(issue.findings.single.line, 4);
      expect(issue.subAgents.single.brief, 'Read only');
    });

    // Harm: a missing detail feature disables the board or a daemon refusal loses its detail words.
    test('standalone reads preserve missing methods and daemon refusals', () async {
      daemon.remove('GetStory');
      daemon.remove('ListStoryIssues');
      daemon.remove('GetIssue');
      await expectLater(client.getStory('demo', 'S2'), throwsA(isA<FeatureNotSupported>()));
      await expectLater(client.listStoryIssues('demo', 'S2'), throwsA(isA<FeatureNotSupported>()));
      await expectLater(client.getIssue('demo', 'I2'), throwsA(isA<FeatureNotSupported>()));
      for (final method in ['GetStory', 'ListStoryIssues', 'GetIssue']) {
        daemon.fails(method, 'org.fuin.porelo.Tasks1.WorkNotAllowed', {'detail': 'Store locked'});
      }
      final refused = throwsA(
        isA<VarlinkException>().having((error) => error.parameters['detail'], 'detail', 'Store locked'),
      );
      await expectLater(client.getStory('demo', 'S2'), refused);
      await expectLater(client.listStoryIssues('demo', 'S2'), refused);
      await expectLater(client.getIssue('demo', 'I2'), refused);
    });

    // Harm: a move saves a different issue, destination or revision than the one reviewed.
    test('issue moves use the agreed request and retain daemon refusal fields', () async {
      daemon.method('SaveMoves', (parameters) {
        expect(parameters, {
          'project': 'demo',
          'moves': [
            {'issue': 'sample', 'to': 'Review'},
          ],
          'revision': 'r1',
        });
        return {'revision': 'r2'};
      });
      expect((await client.saveMoves('demo', [const PlanningIssueMove('sample', 'Review')], 'r1')).revision, 'r2');
      for (final refusal in <String, Map<String, dynamic>>{
        'StaleRevision': {'revision': 'r3'},
        'MoveNotAllowed': {'item': 'sample', 'from': 'Working', 'to': 'Review', 'reason': 'Policy refuses'},
        'StateNotAllowed': {'item': 'sample', 'from': 'Working', 'to': 'Review', 'reason': 'State refuses'},
        'EnteredOnlyByWork': {'item': 'sample', 'to': 'Review'},
      }.entries) {
        daemon.fails('SaveMoves', 'org.fuin.porelo.Tasks1.${refusal.key}', refusal.value);
        await expectLater(
          client.saveMoves('demo', [const PlanningIssueMove('sample', 'Review')], 'r1'),
          throwsA(
            isA<VarlinkException>()
                .having((error) => error.simpleName, 'name', refusal.key)
                .having((error) => error.parameters, 'parameters', refusal.value),
          ),
        );
      }
      daemon.remove('SaveMoves');
      await expectLater(
        client.saveMoves('demo', [const PlanningIssueMove('sample', 'Review')], 'r1'),
        throwsA(isA<FeatureNotSupported>()),
      );
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
      daemon.fails('WatchStories', 'org.fuin.porelo.Tasks1.WorkNotAllowed', {'detail': 'cannot read the store'});
      await expectLater(
        client.watchStories('demo'),
        emitsError(
          isA<VarlinkException>().having((error) => error.parameters['detail'], 'detail', 'cannot read the store'),
        ),
      );
    });
  });
}
