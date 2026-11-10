import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';
import '../support/planning_embedding.dart';

Future<void> _primeCancellation() async {
  final stream = StreamController<void>.broadcast();
  await stream.stream.listen((_) {}).cancel();
  await stream.close();
}

void main() {
  // Harm: terminal planning replies remain invisible until the widget test has already failed.
  for (final unsupported in [false, true]) {
    test('planning errors reach their consumer clock, unsupported: $unsupported', () async {
      await _primeCancellation();
      late FakeBackend backend;
      late PlanningBoard board;
      fakeAsync((clock) {
        backend = FakeBackend([]);
        board = PlanningBoard(FleetPlanningSource(backend), 'checkout');
        clock.flushMicrotasks();
        expect(board.live, isTrue);
        backend.failPlanning(
          unsupported
              ? const FeatureNotSupported('planning')
              : const VarlinkException('WorkNotAllowed', {'detail': 'cannot read planning'}),
        );
        clock.flushMicrotasks();
        try {
          expect(board.live, isFalse);
          if (unsupported) {
            expect(board.unsupported, isTrue);
          } else {
            expect(board.problem, contains('cannot read planning'));
          }
          expect(backend.planningWatchers, 0);
        } finally {
          board.dispose();
        }
      });
      await backend.stop();
    });
  }

  // Harm: normal completion is invisible, and teardown hangs by closing the same stream in another clock.
  test('planning completion is observed and backend teardown finishes across clocks', () async {
    await _primeCancellation();
    late FakeBackend backend;
    late PlanningBoard board;
    fakeAsync((clock) {
      backend = FakeBackend([]);
      board = PlanningBoard(FleetPlanningSource(backend), 'checkout');
      clock.flushMicrotasks();
      expect(board.live, isTrue);
      unawaited(backend.endPlanning());
      clock.flushMicrotasks();
      try {
        expect(board.problem, isNull);
        expect(board.live, isTrue);
        expect(backend.planningWatchers, 0);
      } finally {
        board.dispose();
      }
    });
    await backend.stop().timeout(const Duration(seconds: 1));
  });
  // Harm: retry waits on a terminal subscription's cached cancellation instead of opening a new watch.
  test('retry after a refusal re-watches within the consumer clock', () async {
    await _primeCancellation();
    late FakeBackend backend;
    late PlanningBoard board;
    fakeAsync((clock) {
      backend = FakeBackend([]);
      board = PlanningBoard(FleetPlanningSource(backend), 'checkout');
      clock.flushMicrotasks();
      try {
        expect(board.live, isTrue);
        backend.failPlanning(const VarlinkException('WorkNotAllowed', {'detail': 'Planning store cannot be read'}));
        clock.flushMicrotasks();
        expect(board.problem, 'Planning store cannot be read');
        expect(board.live, isFalse);
        unawaited(board.retry());
        clock.flushMicrotasks();
        expect(board.problem, isNull);
        expect(board.live, isTrue);
        backend.pushPlanning('checkout', {
          'states': <Map<String, dynamic>>[],
          'phases': <Map<String, dynamic>>[],
          'stories': <Map<String, dynamic>>[],
          'revision': 'after-retry',
        });
        clock.flushMicrotasks();
        expect(board.snapshot!.revision, 'after-retry');
        expect(board.stories, isEmpty);
      } finally {
        board.dispose();
      }
    });
    await backend.stop().timeout(const Duration(seconds: 1));
  });
}
