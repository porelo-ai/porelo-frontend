import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/app/story_work.dart';

import '../features/support/world.dart';

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeBackend backend;
  late PlanningBoard board;
  late StoryWork work;
  setUp(() async {
    backend = FakeBackend([]);
    board = PlanningBoard(backend, 'checkout');
    await _turn();
    work = StoryWork(board, board.stories.firstWhere((story) => story.id == 'ST291'), 'Implementing');
    await work.load();
  });
  tearDown(() async {
    work.dispose();
    board.dispose();
    await backend.stop();
  });

  // Harm: a start runs in a mode the project does not allow.
  test('only allowed modes can start', () async {
    final proposal = backend.storyWork.call('ProposeStoryWork', {
      'project': 'checkout',
      'story': 'ST291',
      'to': 'Implementing',
    });
    backend.storyWork.proposals['ST291'] = {
      ...proposal,
      'modes': ['UNATTENDED'],
    };
    await work.load();
    work.chooseMode('AGENT');
    expect(await work.start(), isFalse);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork'), isEmpty);
    work.chooseMode('UNATTENDED');
    expect(await work.start(), isTrue);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork').single.$2['mode'], 'UNATTENDED');
  });

  // Harm: dropping a reader silently removes review of outgoing work.
  test('drop requires a comment and sends no replacement agent', () async {
    final repo = work.proposal!.repositories.first;
    final reader = repo.subAgents.firstWhere((sub) => sub.role == 'READER');
    work.choose(repo.repository, reader, 'DROP');
    expect(work.canStart, isFalse);
    expect(await work.start(), isFalse);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork'), isEmpty);
    work.setComment('Use the repository review outside this run.');
    expect(await work.start(), isTrue);
    final request = backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork').single.$2;
    final sent =
        (((request['repositories'] as List).cast<Map<String, dynamic>>().firstWhere(
                  (item) => item['repository'] == repo.repository,
                ))['subAgents']
                as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['id'] == reader.id);
    expect(sent['choice'], 'DROP');
    expect(sent['brief'], reader.brief);
    expect(sent['agent'], reader.agent);
    expect(request['comment'], 'Use the repository review outside this run.');
  });

  // Harm: a changed participant or limit is ignored by the actual start request.
  test('changed reader and per issue rounds reach start exactly', () async {
    final repo = work.proposal!.repositories.first;
    final sub = repo.subAgents.firstWhere((sub) => sub.role == 'READER');
    final issue = work.proposal!.issues.first.id;
    work.choose(repo.repository, sub, 'CHANGE', agent: 'claude-code', model: 'chosen-model');
    work.setComment('Use a different participant.');
    work.setRounds('5');
    work.setRounds('7', issue);
    expect(await work.start(), isTrue);
    final request = backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork').single.$2;
    expect(request['readingRounds'], 5);
    expect(request['issueReadingRounds'], [
      {'issue': issue, 'rounds': 7},
    ]);
    final selected =
        (((request['repositories'] as List).cast<Map<String, dynamic>>().firstWhere(
                  (item) => item['repository'] == repo.repository,
                ))['subAgents']
                as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['id'] == sub.id);
    expect(selected['choice'], 'CHANGE');
    expect(selected['agent'], 'claude-code');
    expect(selected['model'], 'chosen-model');
  });

  // Harm: invalid limits disable reading or send a different value from the one entered.
  test('invalid reading limits prevent any start', () async {
    for (final value in ['', '0', '-1', '1.5', 'many']) {
      work.setRounds(value);
      expect(work.canStart, isFalse, reason: value);
      expect(await work.start(), isFalse, reason: value);
    }
    work.setRounds('3');
    work.setRounds('0', work.proposal!.issues.first.id);
    expect(await work.start(), isFalse);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork'), isEmpty);
  });

  // Harm: a refusal moves a card locally and hides the machine's explanation.
  test('refusal keeps the board and exposes detail', () async {
    backend.storyWork.refusal = 'This repository cannot start on this machine.';
    expect(await work.start(), isFalse);
    expect(work.problem, 'This repository cannot start on this machine.');
    expect(board.stories.firstWhere((story) => story.id == 'ST291').state, 'Backlog');
  });

  // Harm: work is sent with an obsolete proposal after another board revision arrives.
  test('a stale proposal cannot start', () async {
    final snapshot = Map<String, dynamic>.of(backend.planning['checkout']!)..['revision'] = 'new';
    backend.pushPlanning('checkout', snapshot);
    await _turn();
    expect(await work.start(), isFalse);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork'), isEmpty);
  });

  // Harm: an unversioned board lets work start without detecting concurrent changes.
  test('a board without a revision cannot authorize a start', () async {
    backend.pushPlanning('checkout', {...backend.planning['checkout']!, 'revision': ''});
    await _turn();
    work.dispose();
    work = StoryWork(board, board.stories.firstWhere((story) => story.id == 'ST291'), 'Implementing');
    await work.load();
    expect(await work.start(), isFalse);
    expect(backend.storyWork.calls.where((call) => call.$1 == 'StartStoryWork'), isEmpty);
  });

  // Harm: a successful response fabricates a state before the daemon's board echo.
  test('start waits for the board echo', () async {
    backend.storyWork.deferEcho = true;
    expect(await work.start(), isTrue);
    expect(board.stories.firstWhere((story) => story.id == 'ST291').state, 'Backlog');
  });
}
