@Tags(['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

void main() {
  late MockDaemon daemon;
  late PoreloClient client;
  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    client = await PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'story mock'));
  });
  tearDown(() => daemon.stop());

  // Harm: a proposal or work-order request reaches the wrong project or target.
  test('proposal fields and source arguments round trip over the socket', () async {
    daemon.method('ProposeStoryWork', (parameters) {
      expect(parameters, {'project': 'demo', 'story': 'story', 'to': 'Building'});
      return {
        'modes': ['AGENT'],
        'startLabel': 'Start the build',
        'readingRounds': 4,
        'modeDetails': [
          {'mode': 'AGENT', 'words': 'Work together.', 'workOrder': 'Ask before deciding.'},
        ],
        'repositories': [
          {
            'repository': 'repo',
            'task': 'task',
            'agent': 'agent',
            'model': 'model',
            'modelHint': 'Repository default.',
            'issues': ['item'],
            'workOrder': 'Build the item.',
          },
        ],
        'coordinator': {'agent': 'agent', 'model': 'model', 'sentence': 'The running coordinator is told.'},
      };
    });
    final proposal = await client.proposeStoryWork('demo', 'story', 'Building');
    expect(proposal.modeDetails.single.words, 'Work together.');
    expect(proposal.repositories.single.issues, ['item']);
    expect(proposal.repositories.single.modelHint, 'Repository default.');
    expect(proposal.repositories.single.workOrder, 'Build the item.');
    expect(proposal.coordinator!.sentence, 'The running coordinator is told.');
    expect(proposal.startLabel, 'Start the build');
  });

  // Harm: chosen main or sub-agents and limits are discarded, or terminal opening needs a lagging task list.
  test('start sends every choice and reads returned tasks without another call', () async {
    daemon.method('StartStoryWork', (parameters) {
      expect(parameters, {
        'project': 'demo',
        'story': 'story',
        'to': 'Building',
        'mode': 'AGENT',
        'revision': 'r1',
        'repositories': [
          {'repository': 'repo', 'agent': 'changed', 'model': 'chosen'},
        ],
        'subAgents': [
          {'repository': 'repo', 'name': 'reader', 'choice': 'DROP'},
        ],
        'comment': '  Explain the choice.  ',
        'readingRounds': 5,
        'issueReadingRounds': [
          {'issue': 'item', 'rounds': 7},
        ],
      });
      return {
        'started': true,
        'revision': 'r2',
        'tasks': [
          {'name': 'task', 'running': true, 'agent': 'changed', 'model': 'chosen', 'mode': 'SHELL'},
        ],
        'coordinator': {'name': 'coordinator', 'running': true, 'mode': 'SHELL'},
      };
    });
    final answer = await client.startStoryWork(
      const StoryWorkRequest(
        project: 'demo',
        story: 'story',
        to: 'Building',
        mode: 'AGENT',
        revision: 'r1',
        repositories: [StoryWorkMainAgent(repository: 'repo', agent: 'changed', model: 'chosen')],
        subAgents: [StoryWorkChoice(repository: 'repo', name: 'reader', choice: 'DROP')],
        comment: '  Explain the choice.  ',
        readingRounds: 5,
        issueReadingRounds: {'item': 7},
      ),
    );
    expect(answer.tasks.single.model, 'chosen');
    expect(answer.terminalTask!.name, 'coordinator');
    expect(answer.revision, 'r2');
    expect(
      StoryWorkStarted.from({
        'tasks': [
          {'name': 'single', 'running': true},
        ],
      }).terminalTask!.name,
      'single',
    );
  });

  // Harm: Stop acts on a different story or an ended reason never reaches attention.
  test('work status and stop preserve project story and daemon detail', () async {
    daemon.method('GetStoryWork', (parameters) {
      expect(parameters, {'project': 'demo', 'story': 'story'});
      return {
        'work': {
          'atWork': false,
          'tasks': ['task'],
        },
        'ended': {'reason': 'Needs the repository key.', 'at': 'instant'},
      };
    });
    daemon.method('StopStoryWork', (parameters) {
      expect(parameters, {'project': 'demo', 'story': 'story'});
      throw const MockRefusal('org.fuin.porelo.Tasks1.PlanningRefused', {'detail': 'The run already ended.'});
    });
    final status = await client.getStoryWork('demo', 'story');
    expect(status.work!.atWork, isFalse);
    expect(status.ended!.reason, 'Needs the repository key.');
    await expectLater(
      client.stopStoryWork('demo', 'story'),
      throwsA(
        isA<VarlinkException>().having((error) => error.parameters['detail'], 'detail', 'The run already ended.'),
      ),
    );
  });

  // Harm: findings or a decision target a different issue, round or revision.
  test('GetIssue and each reading decision use the exact issue round and revision', () async {
    daemon.method('GetIssue', (parameters) {
      expect(parameters, {'project': 'demo', 'issue': 'item'});
      return {
        'findings': [
          {'severity': 'NOTE', 'text': 'Later.'},
          {'severity': 'BLOCKING', 'text': 'A credential escapes.'},
        ],
      };
    });
    final detail = await client.getPlanningIssue('demo', 'item');
    expect(detail.blockingFirst.first.text, 'A credential escapes.');
    for (final choice in ['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK']) {
      daemon.method('ResolveIssueReading', (parameters) {
        expect(parameters, {
          'project': 'demo',
          'issue': 'item',
          'round': 3,
          'choice': choice,
          'revision': 'r1',
          if (choice == 'REWORK') 'comment': 'Keep the credential inside.',
        });
        return {'revision': 'r2'};
      });
      expect(
        await client.resolveIssueReading(
          'demo',
          'item',
          3,
          choice,
          'r1',
          comment: choice == 'REWORK' ? 'Keep the credential inside.' : null,
        ),
        'r2',
      );
    }
  });

  // Harm: independently registered methods pass tests while the default daemon handlers are broken.
  test('stateful daemon handlers start stop and resolve the story', () async {
    final snapshot = await client.stories('demo');
    final proposal = await client.proposeStoryWork('demo', 'ST291', 'Implementing');
    final started = await client.startStoryWork(
      StoryWorkRequest(
        project: 'demo',
        story: 'ST291',
        to: 'Implementing',
        mode: 'AGENT',
        revision: snapshot.revision,
        subAgents: [],
        repositories: [
          for (final repo in proposal.repositories)
            StoryWorkMainAgent(repository: repo.repository, agent: repo.agent, model: repo.model),
        ],
      ),
    );
    expect(started.tasks, hasLength(2));
    expect(started.terminalTask!.name, 'coordinator');
    expect((await client.getStoryWork('demo', 'ST291')).work!.atWork, isTrue);
    await client.stopStoryWork('demo', 'ST291');
    expect((await client.getStoryWork('demo', 'ST291')).work!.atWork, isFalse);
    final board = daemon.planningFor({'project': 'demo'});
    final story = (board['stories'] as List).cast<Map<String, dynamic>>().firstWhere((story) => story['id'] == 'ST291');
    final issue = (story['issues'] as List).first as Map<String, dynamic>;
    issue.addAll({'readingStopped': true, 'rounds': 3});
    daemon.storyWork.findings['B540'] = [
      {'severity': 'BLOCKING', 'text': 'Keep the key inside.'},
    ];
    expect((await client.getPlanningIssue('demo', 'B540')).findings.single.text, 'Keep the key inside.');
    await client.resolveIssueReading('demo', 'B540', 3, 'REVIEW_ANYWAY', board['revision'] as String);
    expect(
      (await client.stories('demo')).stories.firstWhere((story) => story.id == 'ST291').issues.first.readingStopped,
      isFalse,
    );
  });
}
