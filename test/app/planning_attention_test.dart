import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

Map<String, dynamic> _snapshot(
  String revision, {
  bool stopped = false,
  bool working = false,
  String state = 'Building',
}) => {
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
        {'id': 'item', 'repository': 'repo', 'state': state, 'readingStopped': stopped, 'rounds': 3},
      ],
    },
  ],
};
Future<void> _turn() => Future<void>.delayed(Duration.zero);

class _Planning extends MockPlanningSource {
  _Planning(Map<String, dynamic> snapshot) {
    boards['demo'] = snapshot;
  }
  StoryWorkStatus status = StoryWorkStatus.from({});
  Object? workError;
  @override
  Future<StoryWorkStatus> getStoryWork(String project, String story) async {
    if (workError case final error?) throw error;
    return status;
  }
}

/// Two working stories, `story` and `other`, whose work reads fail where [failing] names them.
class _TwoStories extends _Planning {
  _TwoStories(String at)
    : super({
        ..._snapshot('initial', working: true),
        'stories': [
          for (final id in ['story', 'other']) {'id': id, 'state': 'Building', 'issues': <Object>[]},
        ],
      }) {
    status = StoryWorkStatus.from({
      'work': {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
            'ended': {'at': at, 'outcome': 'BLOCKED', 'why': 'Needs a repository key.', 'answer': ''},
          },
        ],
      },
    });
  }
  final Set<String> failing = {};
  @override
  Future<StoryWorkStatus> getStoryWork(String project, String story) async {
    if (failing.contains(story)) {
      throw mockRefusal('org.fuin.porelo.Tasks1.Refused', {'detail': 'Work cannot be read.'});
    }
    return status;
  }
}

class _HeldWatch extends _Planning {
  _HeldWatch(super.snapshot);
  final waiting = StreamController<PlanningSnapshot>();
  @override
  Stream<PlanningSnapshot> watchStories(String project) => waiting.stream;
}

/// A machine that lists one project and serves [planning] for it.
class _Backend extends FakeBackend {
  _Backend(this.planning) : super([]) {
    theProjectsItHas = [
      Project.from({'name': 'demo'}),
    ];
  }
  final _Planning planning;
}

class _Environment {
  final store = MemorySettingsStore();
  late final settings = Settings(store);
  final local = FakeBackend([])..theProjectsItHas = [];
  late _Backend active;
  late Machines machines;
  late MockPlanningClient client;
  late PlanningBoards boards;
  late Attention attention;
  final backends = <_Backend>[];
  Future<void> open(_Backend backend) async {
    await settings.load();
    active = backend;
    backends.add(backend);
    machines = Machines(
      settings,
      reach: (machine) => machine.kind == 'host' && machine.name == 'builder' ? active : local,
      tunnels: FakeTunnels(),
    );
    await machines.add(const Machine(name: 'builder', socketPath: '/tmp/builder.sock', kind: 'host'));
    await Future.wait([for (final machine in machines.all) machines.of(machine).untilAsked()]);
    final idle = MockPlanningSource();
    client = MockPlanningClient(
      () => [
        for (final machine in machines.all)
          PlanningProvider(
            name: machine.name,
            connected: machines.of(machine).reachability == Reachability.connected,
            projects: [for (final project in machines.of(machine).listedProjects) project.name],
            source: switch (machines.of(machine).backend) {
              final _Backend backend => backend.planning,
              _ => idle,
            },
          ),
      ],
      changes: machines,
      currentProvider: () => machines.current.name,
      chosenProject: () => machines.fleet.selectedProject?.name,
    );
    boards = PlanningBoards(client);
    attention = Attention(machines, settings)..planning = boards;
    await _turn();
  }

  List<String> get planningRows => rowsOf(attention);

  List<String> rowsOf(Attention attention) => [
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
    client.dispose();
    machines.dispose();
    settings.dispose();
    for (final backend in backends) {
      if (backend.planning case final _HeldWatch held) await held.waiting.close();
      await backend.planning.end();
      await backend.stop();
    }
    await local.stop();
  }
}

void main() {
  // Harm: a connection replacement leaves a reading stuck or clears it before an authoritative replacement arrives.
  test('real PlanningBoards notifications retain then clear a replacement reading', () async {
    final env = _Environment();
    await env.open(_Backend(_Planning(_snapshot('first', stopped: true))));
    addTearDown(env.close);
    final old = env.boards.sources.single;
    expect(env.planningRows, ['reading builder/demo/item']);
    final replacement = _HeldWatch(_snapshot('second'));
    await env.replace(_Backend(replacement));
    expect(old.isDisposed, isTrue);
    expect(env.boards.sources.single.live, isFalse);
    expect(env.planningRows, ['reading builder/demo/item']);
    replacement.waiting.add(PlanningSnapshot.from(replacement.boards['demo']!));
    await _turn();
    expect(env.boards.sources.single.live, isTrue);
    expect(env.planningRows, isEmpty);
  });

  // Harm: failed work reads silently resolve an outcome that still needs the person.
  test('real board notifications retain ended attention on errors and unsupported methods', () async {
    final planning = _Planning(_snapshot('initial', working: true));
    final backend = _Backend(planning);
    planning.status = StoryWorkStatus.from({
      'work': {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
            'ended': {'at': 'instant', 'outcome': 'BLOCKED', 'why': 'Needs a repository key.', 'answer': ''},
          },
        ],
      },
    });
    final env = _Environment();
    await env.open(backend);
    addTearDown(env.close);
    expect(env.planningRows, ['story ended builder/demo/story']);
    for (final error in <Object>[
      mockRefusal('org.fuin.porelo.Tasks1.Refused', {'detail': 'Work cannot be read.'}),
      const PlanningUnsupported('this backend has no story work'),
    ]) {
      planning.workError = error;
      planning.push('demo', _snapshot('failed-$error', working: true));
      await _turn();
      final source = env.boards.sources.single;
      expect(source.storyWork, isEmpty);
      expect(source.workOf(source.stories.single), isNull);
      expect(source.endedOf(source.stories.single), isNull);
      expect(env.planningRows, ['story ended builder/demo/story']);
      if (error is PlanningRefusal) {
        expect(source.workProblems, {'story': 'Work cannot be read.'});
      } else {
        expect(source.workUnsupported, {'story'});
      }
      planning.workError = null;
      planning.push('demo', _snapshot('recovered-$error', working: true));
      await _turn();
      expect(env.planningRows, ['story ended builder/demo/story']);
    }
    planning.push('demo', _snapshot('waiting'));
    await _turn();
    expect(env.planningRows, isEmpty);
    expect(env.boards.sources.single.storyWork, isEmpty);
  });

  // Harm: a story's ended work that only informs can never be put away, comes back at every start, or once seen hides
  // a later end of the same story.
  test("a story's ended work is seen until the story's work ends again", () async {
    final planning = _Planning(_snapshot('initial', working: true));
    StoryWorkStatus endedAt(String at) => StoryWorkStatus.from({
      'work': {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
            'ended': {'at': at, 'outcome': 'BLOCKED', 'why': 'Needs a repository key.', 'answer': ''},
          },
        ],
      },
    });
    planning.status = endedAt('2026-11-10T09:00:00Z');
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(env.planningRows, ['story ended builder/demo/story']);

    env.attention.storyEndSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.planningRows, isEmpty, reason: 'seen');

    final again = Attention(env.machines, env.settings)..planning = env.boards;
    addTearDown(again.dispose);
    await _turn();
    expect(env.rowsOf(again), isEmpty, reason: 'seen stays seen past a restart');

    planning.status = endedAt('2026-11-10T10:00:00Z');
    planning.push('demo', _snapshot('ended-again', working: true));
    await _turn();
    expect(env.planningRows, ['story ended builder/demo/story'], reason: 'its work ended again');
  });
  // Harm: a story's end seen once comes back, because another story was seen while its work could not be read.
  test("a story's seen end is kept while its work cannot be read", () async {
    final planning = _TwoStories('2026-11-10T09:00:00Z');
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    AttentionRow rowOf(String story) => env.attention.openRows.firstWhere((row) => row.id.endsWith('/$story'));
    expect(env.planningRows, ['story ended builder/demo/story', 'story ended builder/demo/other']);
    env.attention.storyEndSeen(rowOf('story'));
    await _turn();

    planning.failing.add('story');
    planning.push('demo', {...planning.boards['demo']!, 'revision': 'unreadable'});
    await _turn();
    env.attention.storyEndSeen(rowOf('other'));
    await _turn();

    planning.failing.clear();
    planning.push('demo', {...planning.boards['demo']!, 'revision': 'read again'});
    await _turn();
    expect(env.planningRows, isEmpty, reason: 'both were seen');
  });

  // Harm: a planner's stopped reading could not be put away, so rows a person had read filled Needs you; or one put
  // away came back at every start of the window.
  test('a stopped reading put away stays away past a restart until its state changes', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(env.planningRows, ['reading builder/demo/item']);

    env.attention.readingSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.planningRows, isEmpty, reason: 'put away');

    final reloaded = Settings(env.store);
    await reloaded.load();
    final again = Attention(env.machines, reloaded)..planning = env.boards;
    addTearDown(() {
      again.dispose();
      reloaded.dispose();
    });
    await _turn();
    expect(env.rowsOf(again), isEmpty, reason: 'put away stays put away past a restart');

    planning.push('demo', _snapshot('moved', stopped: true, state: 'Review'));
    await _turn();
    expect(env.planningRows, ['reading builder/demo/item'], reason: "the issue's state changed");
    expect(env.rowsOf(again), ['reading builder/demo/item'], reason: 'in the restarted window too');
  });

  // Harm: a stopped reading put away hid the issue's next stop with the same reason and state, after its board had
  // stopped saying it; or a board that could not be read forgot what was put away.
  test('a stopped reading put away is said again once its board stops saying it and says it again', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    env.attention.readingSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.settings.readingsPutAway, hasLength(1), reason: 'kept in the settings');

    final held = _HeldWatch(_snapshot('replaced'));
    await env.replace(_Backend(held));
    expect(env.boards.sources.single.live, isFalse);
    expect(env.settings.readingsPutAway, hasLength(1), reason: 'a board not read yet forgets nothing');
    held.waiting.add(PlanningSnapshot.from(_snapshot('resumed')));
    await _turn();
    expect(env.settings.readingsPutAway, isEmpty, reason: 'the board, read whole, no longer says it');

    held.waiting.add(PlanningSnapshot.from(_snapshot('stopped again', stopped: true)));
    await _turn();
    expect(env.planningRows, ['reading builder/demo/item'], reason: 'its next stop is said');
  });
}
