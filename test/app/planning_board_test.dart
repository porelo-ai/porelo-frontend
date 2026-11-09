import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

class _Backend extends Fake implements FleetBackend {
  final controllers = <String, StreamController<PlanningSnapshot>>{};
  final canceled = <String>[];
  @override
  Stream<PlanningSnapshot> watchStories(String project) => controllers
      .putIfAbsent(
        project,
        () => StreamController<PlanningSnapshot>(
          sync: true,
          onCancel: () {
            canceled.add(project);
          },
        ),
      )
      .stream;
}

PlanningSnapshot _snapshot(String id) => PlanningSnapshot.from({
  'states': [
    {'name': 'Building', 'kind': 'WORKING'},
  ],
  'phases': [
    {
      'name': 'Build',
      'states': ['Building'],
    },
  ],
  'stories': [
    {'id': id, 'state': 'Building', 'title': 'A story', 'priority': 'High'},
  ],
  'revision': id,
});

void main() {
  // Harm: a synchronous refusal leaves a board looking live or offers calls an older daemon cannot serve.
  for (final (failure, unsupported, words) in const <(Object, bool, String?)>[
    (FeatureNotSupported('planning'), true, null),
    (VarlinkException('org.varlink.service.MethodNotFound', {'method': 'WatchStories'}), true, null),
    (
      VarlinkException('org.fuin.porelo.Tasks1.PlanningRefused', {'detail': 'Planning store cannot be read'}),
      false,
      'Planning store cannot be read',
    ),
  ]) {
    test('a synchronous watch failure marks the board unavailable: $failure', () {
      final board = PlanningBoard(_SynchronousFailure(failure), 'project');
      addTearDown(board.dispose);
      expect(board.live, isFalse);
      expect(board.unsupported, unsupported);
      expect(board.problem, words);
    });
  }

  // Harm: the unsupported-planning page attributes the refusal to another machine after selection changes.
  test('when no provider offers planning the selected board belongs to the current machine', () async {
    final first = FakeBackend([])..withoutPlanning = true;
    final second = FakeBackend([])..withoutPlanning = true;
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (machine) => machine.name == 'other' ? second : first,
      tunnels: FakeTunnels(),
    );
    final boards = PlanningBoards(machines);
    addTearDown(() async {
      boards.dispose();
      machines.dispose();
      await first.stop();
      await second.stop();
    });
    final local = machines.current;
    const other = Machine(name: 'other', socketPath: '/tmp/other.sock');
    await machines.add(other);
    await Future<void>.delayed(Duration.zero);
    expect(boards.projects, isEmpty);
    expect(boards.selected!.unsupported, isTrue);
    expect(boards.selected!.backend, same(first));

    machines.select(other);
    expect(boards.selected!.unsupported, isTrue);
    expect(boards.selected!.backend, same(second));

    machines.select(local);
    expect(boards.selected!.backend, same(first));
  });

  // Harm: a silent subscription keeps a project or a disposed window alive indefinitely.
  test('disposing cancels a watch even when it has never answered', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'first');
    var notifications = 0;
    board.addListener(() {
      notifications++;
    });
    board.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(backend.canceled, ['first']);
    backend.controllers['first']!.add(_snapshot('late'));
    expect(notifications, 0);
    await backend.controllers['first']!.close();
  });

  // Harm: an old project's answer is shown below another project's name.
  test('changing project cancels the old watch and rejects its late replies', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'first');
    addTearDown(board.dispose);
    backend.controllers['first']!.add(_snapshot('old'));
    expect(board.stories.single.id, 'old');
    await board.changeProject(backend, 'second');
    expect(backend.canceled, ['first']);
    expect(board.snapshot, isNull);
    backend.controllers['first']!.add(_snapshot('late'));
    backend.controllers['second']!.add(_snapshot('new'));
    expect(board.project, 'second');
    expect(board.stories.single.id, 'new');
    await backend.controllers['first']!.close();
  });

  // Harm: deleted stories or old workflow metadata survive a complete replacement.
  test('each answer replaces the entire snapshot including deletions', () {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    backend.controllers['project']!.add(_snapshot('old'));
    expect(board.workingCount, 1);
    backend.controllers['project']!.add(
      PlanningSnapshot.from({
        'states': <Map<String, dynamic>>[],
        'phases': <Map<String, dynamic>>[],
        'stories': <Map<String, dynamic>>[],
        'revision': 'empty',
      }),
    );
    expect(board.stories, isEmpty);
    expect(board.phases, isEmpty);
    expect(board.states, isEmpty);
    expect(board.snapshot!.revision, 'empty');
    expect(board.workingCount, 0);
  });

  // Harm: losing a stream is mistaken for an empty or current board.
  test('errors preserve their words and make the last snapshot stale', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    backend.controllers['project']!.add(_snapshot('retained'));
    backend.controllers['project']!.addError(
      const VarlinkException('PlanningRefused', {'detail': 'cannot read the store'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(board.problem, 'cannot read the store');
    expect(board.live, isFalse);
    expect(board.workingCount, isNull);
    expect(board.stories.single.id, 'retained');
  });

  // Harm: a daemon refusal is replaced by a raw exception or a malformed parameter instead of its words.
  test('planning refusal words prefer detail and then message without stringifying other values', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    final cases = <(Map<String, dynamic>, String)>[
      ({'detail': 'The detail', 'message': 'The message'}, 'The detail'),
      ({'detail': ' ', 'message': 'The message'}, 'The message'),
      ({'detail': 7, 'message': 'The message'}, 'The message'),
      ({'detail': 7, 'message': false}, 'Refused: PlanningRefused.'),
    ];
    for (final (parameters, words) in cases) {
      backend.controllers['project']!.addError(VarlinkException('org.fuin.porelo.Tasks1.PlanningRefused', parameters));
      await Future<void>.delayed(Duration.zero);
      expect(board.problem, words);
      backend.controllers.remove('project');
      await board.retry();
    }
  });

  // Harm: a normally ended stream leaves a frozen board looking current.
  test('a final answer is retained but watch completion is visible', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    backend.controllers['project']!.add(_snapshot('last'));
    expect(board.live, isTrue);
    await backend.controllers['project']!.close();
    expect(board.live, isFalse);
    expect(board.problem, contains('watch ended'));
    expect(board.stories.single.id, 'last');
  });

  // Harm: absent workflow data becomes a reassuring zero or drops an orphan story.
  test('incomplete and inconsistent replies remain unsaid or visibly unplaced', () {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    backend.controllers['project']!.add(PlanningSnapshot.from({}));
    expect(board.workingCount, isNull);
    expect(board.closedCount, isNull);
    backend.controllers['project']!.add(
      PlanningSnapshot.from({
        'states': <Map<String, dynamic>>[],
        'phases': <Map<String, dynamic>>[],
        'stories': [
          {'id': 'orphan', 'state': 'Future state'},
        ],
      }),
    );
    expect(board.unplaced.single.id, 'orphan');
    expect(board.workingCount, isNull);
  });
  // Harm: a failed planning stream cannot be resumed while the machine remains connected.
  test('retry replaces an ended watch without resetting the view choices', () async {
    final backend = _Backend();
    final board = PlanningBoard(backend, 'project');
    addTearDown(board.dispose);
    board.filter(PlanningPriority.high);
    board.search('story');
    backend.controllers['project']!.add(_snapshot('before'));
    await backend.controllers['project']!.close();
    expect(board.problem, contains('watch ended'));
    backend.controllers.remove('project');
    await board.retry();
    backend.controllers['project']!.add(_snapshot('after'));
    expect(board.live, isTrue);
    expect(board.problem, isNull);
    expect(board.stories.single.id, 'after');
    expect(board.preferences.priority, PlanningPriority.high);
    expect(board.preferences.search, 'story');
  });
  // Harm: a refusal stays invisible while cancellation waits on an unresponsive transport.
  test('a watch error is reported before asynchronous cancellation finishes', () async {
    final canceled = Completer<void>();
    final source = StreamController<PlanningSnapshot>(onCancel: () => canceled.future);
    final backend = _SlowCancellation(source);
    final board = PlanningBoard(backend, 'project');
    source.addError(const VarlinkException('PlanningRefused', {'detail': 'store unavailable'}));
    await Future<void>.delayed(Duration.zero);
    try {
      expect(board.problem, contains('store unavailable'));
      expect(board.live, isFalse);
    } finally {
      canceled.complete();
      board.dispose();
      await source.close();
    }
  });
}

class _SlowCancellation extends Fake implements FleetBackend {
  _SlowCancellation(this.source);
  final StreamController<PlanningSnapshot> source;
  @override
  Stream<PlanningSnapshot> watchStories(String project) => source.stream;
}

class _SynchronousFailure extends Fake implements FleetBackend {
  _SynchronousFailure(this.failure);
  final Object failure;

  @override
  Stream<PlanningSnapshot> watchStories(String project) => throw failure;
}
