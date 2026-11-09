import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/app/story_work.dart';
import 'package:porelo_frontend/src/mock/planning_data.dart';

import '../features/support/world.dart';

void main() {
  late FakeBackend backend;
  late PlanningBoard board;
  late ReadingDecision reading;
  late String issue;
  setUp(() async {
    backend = FakeBackend([]);
    final snapshot = mockPlanningBoard();
    final story = (snapshot['stories'] as List).cast<Map<String, dynamic>>().firstWhere(
      (story) => story['id'] == 'ST291',
    );
    final stopped = (story['issues'] as List).first as Map<String, dynamic>;
    issue = stopped['id'] as String;
    stopped.addAll({'state': 'Reading', 'rounds': 3, 'roundsMost': 3, 'readingStopped': true});
    backend.planning['checkout'] = snapshot;
    backend.storyWork.findings[issue] = [
      {'severity': 'NOTE', 'text': 'A small concern.'},
      {'severity': 'BLOCKING', 'text': 'A credential would escape.'},
    ];
    board = PlanningBoard(backend, 'checkout');
    await Future<void>.delayed(Duration.zero);
    final shown = board.stories.firstWhere((story) => story.id == 'ST291');
    reading = ReadingDecision(PlanningAttention(board, shown, issue: shown.issues.first));
    await reading.load();
  });
  tearDown(() async {
    reading.dispose();
    board.dispose();
    await backend.stop();
  });

  // Harm: a reading decision targets the wrong issue, round or revision.
  test('all three decisions preserve the exact issue round and revision', () async {
    backend.storyWork.deferEcho = true;
    for (final choice in ['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK']) {
      if (reading.submitted) {
        reading.dispose();
        final story = board.stories.firstWhere((story) => story.id == 'ST291');
        reading = ReadingDecision(PlanningAttention(board, story, issue: story.issues.first));
        await reading.load();
      }
      await reading.resolve(choice, comment: choice == 'REWORK' ? 'Keep the credential inside.' : null);
    }
    final calls = backend.storyWork.calls
        .where((call) => call.$1 == 'ResolveIssueReading')
        .map((call) => call.$2)
        .toList();
    expect(calls, [
      for (final choice in ['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK'])
        {
          'project': 'checkout',
          'issue': issue,
          'round': 3,
          'choice': choice,
          'revision': 'design-1',
          if (choice == 'REWORK') 'comment': 'Keep the credential inside.',
        },
    ]);
  });

  // Harm: accepting a reading conceals its findings or sends a duplicate before confirmation.
  test('findings put blocking first and a decision waits for board confirmation', () async {
    backend.storyWork.deferEcho = true;
    expect(reading.detail!.blockingFirst.map((finding) => finding.severity), ['BLOCKING', 'NOTE']);
    await reading.resolve('REVIEW_ANYWAY');
    await reading.resolve('REVIEW_ANYWAY');
    expect(backend.storyWork.calls.where((call) => call.$1 == 'ResolveIssueReading'), hasLength(1));
    expect(board.stories.firstWhere((story) => story.id == 'ST291').issues.first.readingStopped, isTrue);
    expect(reading.canResolve, isFalse);
  });

  // Harm: empty rework instructions are submitted or refusal detail is lost.
  test('rework requires text and a refusal remains actionable', () async {
    await reading.resolve('REWORK', comment: '  ');
    expect(backend.storyWork.calls.where((call) => call.$1 == 'ResolveIssueReading'), isEmpty);
    backend.storyWork.refusal = 'The round changed on this machine.';
    await reading.resolve('REWORK', comment: 'Keep the credential inside.');
    expect(reading.problem, 'The round changed on this machine.');
    expect(reading.submitted, isFalse);
    expect(reading.canResolve, isFalse);
    backend.storyWork.refusal = null;
    await reading.load();
    expect(reading.canResolve, isTrue);
  });

  // Harm: a lost planning watch authorizes an action based on stale findings.
  test('a failed watch disables reading decisions', () async {
    backend.failPlanning(const VarlinkDisconnected('Planning stream lost.'));
    await Future<void>.delayed(Duration.zero);
    expect(reading.canResolve, isFalse);
    await reading.resolve('REVIEW_ANYWAY');
    expect(backend.storyWork.calls.where((call) => call.$1 == 'ResolveIssueReading'), isEmpty);
  });
}
