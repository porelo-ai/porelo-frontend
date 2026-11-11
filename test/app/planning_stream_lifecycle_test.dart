import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

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
      late MockPlanningSource backend;
      late PlanningBoard board;
      fakeAsync((clock) {
        backend = MockPlanningSource();
        board = PlanningBoard(backend, 'checkout');
        clock.flushMicrotasks();
        expect(board.live, isTrue);
        backend.fail(
          unsupported
              ? const PlanningUnsupported('this backend has no planning')
              : mockRefusal('WorkNotAllowed', {'detail': 'cannot read planning'}),
        );
        clock.flushMicrotasks();
        try {
          expect(board.live, isFalse);
          if (unsupported) {
            expect(board.unsupported, isTrue);
          } else {
            expect(board.problem, contains('cannot read planning'));
          }
          expect(backend.watchers, 0);
        } finally {
          board.dispose();
        }
      });
      await backend.end();
    });
  }

  // Harm: normal completion is invisible, and teardown hangs by closing the same stream in another clock.
  test('planning completion is observed and backend teardown finishes across clocks', () async {
    await _primeCancellation();
    late MockPlanningSource backend;
    late PlanningBoard board;
    fakeAsync((clock) {
      backend = MockPlanningSource();
      board = PlanningBoard(backend, 'checkout');
      clock.flushMicrotasks();
      expect(board.live, isTrue);
      unawaited(backend.end());
      clock.flushMicrotasks();
      try {
        expect(board.problem, isNull);
        expect(board.live, isFalse, reason: 'a watch that ended is no longer live, and says no problem');
        expect(backend.watchers, 0);
      } finally {
        board.dispose();
      }
    });
    await backend.end().timeout(const Duration(seconds: 1));
  });
  // Harm: retry waits on a terminal subscription's cached cancellation instead of opening a new watch.
  test('retry after a refusal re-watches within the consumer clock', () async {
    await _primeCancellation();
    late MockPlanningSource backend;
    late PlanningBoard board;
    fakeAsync((clock) {
      backend = MockPlanningSource();
      board = PlanningBoard(backend, 'checkout');
      clock.flushMicrotasks();
      try {
        expect(board.live, isTrue);
        backend.fail(mockRefusal('WorkNotAllowed', {'detail': 'Planning store cannot be read'}));
        clock.flushMicrotasks();
        expect(board.problem, 'Planning store cannot be read');
        expect(board.live, isFalse);
        unawaited(board.retry());
        clock.flushMicrotasks();
        expect(board.problem, isNull);
        expect(board.live, isTrue);
        backend.push('checkout', {
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
    await backend.end().timeout(const Duration(seconds: 1));
  });
}
