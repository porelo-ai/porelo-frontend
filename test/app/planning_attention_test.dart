import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/planning_board.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

Map<String, dynamic> _snapshot(String revision, {bool stopped = false, bool working = false}) => {
  'states': [
    {'name': 'Building', 'kind': 'WORKING'},
    {'name': 'Backlog', 'kind': 'WAITING'},
  ],
  'phases': <Map<String, dynamic>>[],
  'revision': revision,
  'stories': [
    {
      'id': 'story',
      'state': working ? 'Building' : 'Backlog',
      'issues': [
        {'id': 'item', 'repository': 'repo', 'readingStopped': stopped, 'rounds': 3},
      ],
    },
  ],
};
Future<void> _turn() => Future<void>.delayed(Duration.zero);

class _Backend extends FakeBackend {
  _Backend(Map<String, dynamic> snapshot) : super([]) {
    planning['demo'] = snapshot;
    theProjectsItHas = [
      Project.from({'name': 'demo'}),
    ];
  }
  StoryWorkStatus status = StoryWorkStatus.from({});
  Object? workError;
  @override
  Future<StoryWorkStatus> getStoryWork(String project, String story) async {
    if (workError case final error?) throw error;
    return status;
  }
}

class _HeldWatch extends _Backend {
  _HeldWatch(super.snapshot);
  final waiting = StreamController<PlanningSnapshot>();
  @override
  Stream<PlanningSnapshot> watchStories(String project) => waiting.stream;
}

class _Environment {
  final settings = Settings(MemorySettingsStore());
  final local = FakeBackend([])..theProjectsItHas = [];
  late _Backend active;
  late Machines machines;
  late PlanningBoards boards;
  late Attention attention;
  final backends = <_Backend>[];
  Future<void> open(_Backend backend) async {
    active = backend;
    backends.add(backend);
    machines = Machines(
      settings,
      reach: (machine) => machine.kind == 'host' && machine.name == 'builder' ? active : local,
      tunnels: FakeTunnels(),
    );
    await machines.add(const Machine(name: 'builder', socketPath: '/tmp/builder.sock', kind: 'host'));
    await Future.wait([for (final machine in machines.all) machines.of(machine).untilAsked()]);
    boards = PlanningBoards(machines);
    attention = Attention(machines)..planning = boards;
    await _turn();
  }

  List<String> get planningRows => [
    for (final row in attention.openRows)
      if (row.kind == AttentionKind.planning) row.id,
  ];
  Future<void> replace(_Backend backend) async {
    active = backend;
    backends.add(backend);
    await machines.add(const Machine(name: 'builder', socketPath: '/tmp/replacement.sock', kind: 'host'));
    await Future.wait([for (final machine in machines.all) machines.of(machine).untilAsked()]);
    await _turn();
  }

  Future<void> close() async {
    attention.dispose();
    boards.dispose();
    machines.dispose();
    settings.dispose();
    for (final backend in backends) {
      if (backend is _HeldWatch) await backend.waiting.close();
      await backend.stop();
    }
    await local.stop();
  }
}

void main() {
  // Harm: a connection replacement leaves a reading stuck or clears it before an authoritative replacement arrives.
  test('real PlanningBoards notifications retain then clear a replacement reading', () async {
    final env = _Environment();
    await env.open(_Backend(_snapshot('first', stopped: true)));
    addTearDown(env.close);
    final old = env.boards.sources.single;
    expect(env.planningRows, ['reading builder/demo/item']);
    final replacement = _HeldWatch(_snapshot('second'));
    await env.replace(replacement);
    expect(old.isDisposed, isTrue);
    expect(env.boards.sources.single.live, isFalse);
    expect(env.planningRows, ['reading builder/demo/item']);
    replacement.waiting.add(PlanningSnapshot.from(replacement.planning['demo']!));
    await _turn();
    expect(env.boards.sources.single.live, isTrue);
    expect(env.planningRows, isEmpty);
  });

  // Harm: ended work is retained from an old snapshot after a failed fallback, or its clearing never reaches attention.
  test('real board notifications clear old fallback work on errors and unsupported methods', () async {
    final backend = _Backend(_snapshot('initial', working: true));
    backend.status = StoryWorkStatus.from({
      'work': {'atWork': false},
      'ended': {'at': 'instant', 'reason': 'Needs a repository key.'},
    });
    final env = _Environment();
    await env.open(backend);
    addTearDown(env.close);
    expect(env.planningRows, ['story ended builder/demo/story']);
    for (final error in <Object>[
      const VarlinkException('org.fuin.porelo.Tasks1.Refused', {'detail': 'Work cannot be read.'}),
      const FeatureNotSupported('story work'),
    ]) {
      backend.workError = error;
      backend.pushPlanning('demo', _snapshot('failed-$error', working: true));
      await _turn();
      final source = env.boards.sources.single;
      expect(source.storyWork, isEmpty);
      expect(source.workOf(source.stories.single), isNull);
      expect(source.endedOf(source.stories.single), isNull);
      expect(env.planningRows, isEmpty);
      if (error is VarlinkException) {
        expect(source.workProblems, {'story': 'Work cannot be read.'});
      } else {
        expect(source.workUnsupported, {'story'});
      }
      backend.workError = null;
      backend.pushPlanning('demo', _snapshot('recovered-$error', working: true));
      await _turn();
      expect(env.planningRows, ['story ended builder/demo/story']);
    }
    backend.pushPlanning('demo', _snapshot('waiting'));
    await _turn();
    expect(env.planningRows, isEmpty);
    expect(env.boards.sources.single.storyWork, isEmpty);
  });
}
