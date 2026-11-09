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

  // Harm: changed helpers lose their identity, brief, or replacements on the wire.
  test('start sends full repository selections and reads recorded work', () async {
    final board = await client.stories('demo');
    final proposal = await client.proposeStoryWork('demo', 'ST291', 'Implementing');
    expect(proposal.revision, board.revision);
    expect(proposal.coordinator, anyOf('START', 'TELL'));
    final repo = proposal.repositories.first;
    final reader = repo.subAgents.firstWhere((sub) => sub.role == 'READER');
    final answer = await client.startStoryWork(
      StoryWorkRequest(
        project: 'demo',
        story: 'ST291',
        to: 'Implementing',
        mode: 'AGENT',
        revision: board.revision,
        proposedRepositories: proposal.repositories,
        repositories: [
          for (final repo in proposal.repositories)
            StoryWorkMainAgent(repository: repo.repository, agent: repo.agent, model: repo.model),
        ],
        subAgents: [
          StoryWorkChoice(
            repository: repo.repository,
            name: reader.id,
            choice: 'CHANGE',
            agent: reader.agent,
            model: 'chosen-model',
          ),
        ],
        comment: '  Use the selected reader.  ',
        readingRounds: 5,
        issueReadingRounds: {'B540': 7},
      ),
    );
    expect(answer.started, isTrue);
    expect(answer.terminalName, 'coordinator');
    expect(answer.work!.repositories.first.subAgents.firstWhere((sub) => sub.id == reader.id).model, 'chosen-model');
    expect(answer.work!.comment, '  Use the selected reader.  ');
    expect(answer.work!.readingRounds, 5);
    expect(answer.work!.issueReadingRounds.single.rounds, 7);
    expect((await client.stopStoryWork('demo', 'ST291')).work!.atWork, isFalse);
  });

  // Harm: an existing coordinator cannot be opened because Start did not create it.
  test('a multi repository start retains its existing coordinator identity', () {
    final answer = StoryWorkStarted.from({
      'work': {
        'coordinator': 'coordinator',
        'atWork': true,
        'repositories': [
          {'repository': 'a'},
          {'repository': 'b'},
        ],
        'tasks': [
          {'task': 'story-a', 'role': 'MAIN', 'atWork': true},
        ],
      },
      'revision': 'r2',
    });
    expect(answer.terminalName, 'coordinator');
    expect(answer.terminalTask, isNull);
  });

  // Harm: a delayed decision resolves the wrong story, issue, round, or revision.
  test('reading decisions include story and preserve their complete answer', () async {
    for (final choice in ['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK']) {
      daemon.method('ResolveIssueReading', (parameters) {
        expect(parameters, {
          'project': 'demo',
          'story': 'story',
          'issue': 'item',
          'round': 3,
          'choice': choice,
          'revision': 'r1',
          'comment': choice == 'REWORK' ? 'Keep the key inside.' : '',
        });
        return {
          'issue': {'id': 'item', 'rounds': 3},
          'work': {'atWork': true},
          'revision': 'r2',
        };
      });
      final result = await client.resolveIssueReading(
        'demo',
        'story',
        'item',
        3,
        choice,
        'r1',
        comment: choice == 'REWORK' ? 'Keep the key inside.' : null,
      );
      expect(result.revision, 'r2');
      expect(result.issue!.rounds, 3);
      expect(result.work!.atWork, isTrue);
    }
  });

  // Harm: an ended task's explanation disappears before reaching attention.
  test('work status reads task outcomes and stop returns the work record', () async {
    final ended = {
      'outcome': 'BLOCKED',
      'why': 'Needs the repository key.',
      'answer': 'Please grant access.',
      'at': 'instant',
    };
    daemon.method(
      'GetStoryWork',
      (_) => {
        'work': {
          'atWork': false,
          'tasks': [
            {'task': 'task', 'ended': ended},
          ],
        },
      },
    );
    final status = await client.getStoryWork('demo', 'story');
    expect(status.ended!.why, 'Needs the repository key.');
    expect(status.ended!.answer, 'Please grant access.');
    daemon.fails('StopStoryWork', 'org.fuin.porelo.Tasks1.WorkNotAllowed', {
      'from': 'Building',
      'to': '',
      'reason': 'The run already ended.',
    });
    await expectLater(
      client.stopStoryWork('demo', 'story'),
      throwsA(
        isA<VarlinkException>().having((error) => error.parameters['reason'], 'reason', 'The run already ended.'),
      ),
    );
  });
}
