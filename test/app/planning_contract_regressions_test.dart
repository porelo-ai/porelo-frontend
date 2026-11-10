import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/planning_data.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';
import '../support/planning_embedding.dart';

Future<void> _turn() => Future<void>.delayed(Duration.zero);

class _HeldListing extends FakeBackend {
  _HeldListing() : super([]);
  Completer<PlanningSnapshot>? listing;
  @override
  Future<PlanningSnapshot> stories(String project) => listing?.future ?? super.stories(project);
}

void main() {
  // Harm: a stale refusal keeps an applicable card in the old column and hides unsaved intent.
  test('stale reread clears a retained move refusal and preserves its destination', () async {
    final backend = FakeBackend([]);
    final board = PlanningBoard(FleetPlanningSource(backend), 'demo');
    addTearDown(() async {
      board.dispose();
      await backend.stop();
    });
    await _turn();
    board.move('ST291', 'Review');
    backend.planningMoveFailure = const VarlinkException('StateNotAllowed', {'item': 'ST291', 'reason': 'Old refusal'});
    await board.save();
    backend.planningMoveFailure = null;
    backend.planning['demo']!['revision'] = 'new';
    await board.save();
    expect(board.pending['ST291']!.problem, isNull);
    expect(board.displayedState(board.stories.firstWhere((story) => story.id == 'ST291')), 'Review');
    expect(board.cards('Review').any((story) => story.id == 'ST291'), isTrue);
  });

  // Harm: a transport or unsupported-action failure leaves a refused card looking moved.
  test('all save failures return unconfirmed cards to their reported state', () async {
    final backend = FakeBackend([]);
    final board = PlanningBoard(FleetPlanningSource(backend), 'demo');
    addTearDown(() async {
      board.dispose();
      await backend.stop();
    });
    await _turn();
    for (final error in <Object>[
      const FeatureNotSupported('SaveMoves'),
      const VarlinkDisconnected('Connection lost'),
    ]) {
      board.move('ST291', 'Review');
      backend.planningMoveFailure = error;
      await board.save();
      final story = board.stories.firstWhere((story) => story.id == 'ST291');
      expect(board.displayedState(story), story.state);
      expect(board.pending['ST291']!.problem, isNotNull);
    }
  });

  // Harm: a watch masks missing application of the save acknowledgement.
  test('save applies confirmed issue identities before a later listing or watch', () async {
    final backend = _HeldListing();
    final board = PlanningBoard(FleetPlanningSource(backend), 'demo');
    addTearDown(() async {
      board.dispose();
      await backend.stop();
    });
    await _turn();
    backend.listing = Completer<PlanningSnapshot>();
    board.moveIssue('B540', 'Review');
    final saving = board.save();
    await _turn();
    expect(board.stories.expand((story) => story.issues).firstWhere((issue) => issue.id == 'B540').state, 'Review');
    expect(board.pending, isEmpty);
    backend.listing!.complete(PlanningSnapshot.from(backend.planning['demo']!));
    await saving;
  });

  // Harm: detail navigation loses a staged move, or a working issue cannot be unstaged individually.
  test('issue drafts outlive detail screens and undo a working source individually', () async {
    final backend = FakeBackend([]);
    final board = PlanningBoard(FleetPlanningSource(backend), 'demo');
    addTearDown(() async {
      board.dispose();
      await backend.stop();
    });
    await _turn();
    final detail = PlanningDetail(board, 'ST291', null);
    await _turn();
    detail.queueMove('B540', 'Review');
    detail.queueMove('B541', 'Review');
    detail.dispose();
    final issue = PlanningDetail(board, 'ST291', 'B540');
    await _turn();
    expect(board.pendingIssues.keys, ['B540', 'B541']);
    issue.dispose();
    final reopened = PlanningDetail(board, 'ST291', null);
    await _turn();
    reopened.queueMove('B540', 'Implementing');
    expect(board.pendingIssues.keys, ['B541']);
    reopened.dispose();
  });

  // Harm: a failed parent read prevents a successful issue refresh from reaching the screen.
  test('successful issue changes survive a failed parent refresh', () async {
    final backend = FakeBackend([]);
    final board = PlanningBoard(FleetPlanningSource(backend), 'demo');
    addTearDown(() async {
      board.dispose();
      await backend.stop();
    });
    await _turn();
    final detail = PlanningDetail(board, 'ST291', 'B541');
    addTearDown(detail.dispose);
    await _turn();
    final stories = (backend.planning['demo']!['stories'] as List).cast<Map<String, dynamic>>();
    final story = stories.firstWhere((story) => story['id'] == 'ST291');
    ((story['issues'] as List)[1] as Map)['title'] = 'Updated issue';
    backend.planningPartFailures['Story'] = const VarlinkException('Unreachable', {
      'detail': 'Parent unavailable',
      'retryAfter': 4,
    });
    await detail.reload();
    expect(detail.issue!.issue!.title, 'Updated issue');
    expect(detail.storyProblem, contains('try again in 4 s'));
  });

  // Harm: switching to another workflow crashes a dropdown or displays a rejected machine.
  testWidgets('machine selection renders the newly selected working state', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = FakeBackend([]), second = FakeBackend([]);
    // The second machine's workflow is its own from the start; WatchStories carries no workflow.
    final data = second.planning['demo'] = mockPlanningBoard();
    (data['states'] as List).add({'name': 'Investigating', 'kind': 'WORKING'});
    (data['states'] as List).removeWhere(
      (state) => (state as Map)['kind'] == 'WORKING' && state['name'] != 'Investigating',
    );
    final a = PlanningBoard(FleetPlanningSource(first), 'demo'), b = PlanningBoard(FleetPlanningSource(second), 'demo');
    await tester.runAsync(_turn);
    final work = planningStoryWork(
      a,
      a.stories.firstWhere((story) => story.id == 'ST291'),
      'In analysis',
      machines: {a: 'first', b: 'second'},
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StoryWorkDialog(work))));
    await World.settle(tester);
    work.changeMachine(b);
    await World.settle(tester);
    expect(tester.widget<DropdownButton<String>>(find.byKey(const Key('story-work-target'))).value, 'Investigating');
    expect(tester.widget<DropdownButton<PlanningBoard>>(find.byKey(const Key('story-work-machine'))).value, same(b));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    work.dispose();
    a.dispose();
    b.dispose();
    await tester.runAsync(() async {
      await first.stop();
      await second.stop();
    });
  });
}
