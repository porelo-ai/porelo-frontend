import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/window_log.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_planning/planning_fake.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/planned_orders.dart';
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

/// One save the planner holds: a window's move of `item`, refused while the forge did not answer.
const _heldSaves = [
  {
    'id': 'group-1',
    'run': false,
    'earlier': false,
    'resendable': true,
    'commands': [
      {
        'id': 'c1',
        'kind': 'SET_FIELDS',
        'target': 'item',
        'state': 'REFUSED',
        'reason': 'Unreachable',
        'subject': 'the forge did not answer',
      },
    ],
    'reason': 'The forge did not answer the save.',
    'changes': [
      {'target': 'item', 'field': 'status', 'now': 'Backlog', 'nowAt': '2026-11-26T07:00:00Z', 'saved': 'In analysis'},
    ],
    'tries': [
      {
        'at': '2026-11-26T07:01:00Z',
        'result': 'REFUSED',
        'reason': 'Unreachable',
        'answer': {'status': 502, 'text': 'Bad gateway', 'requestId': 'req-7f3a'},
      },
    ],
    'answer': {'status': 502, 'text': 'Bad gateway', 'requestId': 'req-7f3a'},
    'saves': ['group-1'],
  },
];

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
            'role': authorRole,
            'readLanded': <String>[],
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

  /// Sends [snapshot] as the board the planner now holds, so its other reads answer the same revision.
  void send(Map<String, dynamic> snapshot) {
    boards['demo'] = snapshot;
    waiting.add(PlanningSnapshot.from(snapshot));
  }
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
    attention = Attention(machines, settings);
    boards = PlanningBoards(client, seen: attention.seen);
    attention.planning = boards;
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
  // Harm: a planner row that says its reason in words only leaves no trace of the planner's own code, so what the
  // planner answered cannot be found in the window's log afterwards.
  test("a stopped run's row is written to the window's log with the planner's code when it resolves", () async {
    final scratch = Directory.systemTemp.createTempSync('planning-attention-log-');
    final before = windowLog;
    windowLog = WindowLog('${scratch.path}/logs', keepPrivate: (_) async {});
    addTearDown(() {
      windowLog = before;
      scratch.deleteSync(recursive: true);
    });
    final stopped = {
      ..._snapshot('stopped'),
      'stories': [
        {
          'id': 'story',
          'state': 'Backlog',
          'issues': [
            {'id': 'item', 'repository': 'repo', 'state': 'Building', 'needsYou': true},
          ],
          'work': {
            'run': '00000000-0000-4000-9000-0000000000aa',
            'atWork': false,
            'tasks': <Object>[],
            'issues': [
              {'issue': 'item', 'reason': 'STOPPED', 'needsYou': true, 'rounds': 0, 'roundsMost': 2},
            ],
          },
        },
      ],
    };
    final planning = _Planning(stopped);
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(env.planningRows, isNotEmpty, reason: 'the stopped run needs the person');

    planning.push('demo', _snapshot('started again'));
    await _turn();
    expect(env.planningRows, isEmpty, reason: 'its work no longer stops');
    final file = File('${scratch.path}/logs/${WindowLog.fileName}');
    final logged = file.existsSync() ? file.readAsLinesSync() : const <String>[];
    expect(logged.where((line) => line.contains('Needs you: resolved')).single, contains('STOPPED'));
  });

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

  // Harm: a row kept while its board is replaced draws the old, disposed board: an assertion in a debug build, and in a
  // release build buttons that do nothing and say no reason.
  testWidgets('a kept row of held saves shows what was held and why it cannot be acted on, its old board unused', (
    tester,
  ) async {
    final env = _Environment();
    late _HeldWatch replacement;
    await tester.runAsync(() async {
      final held = _HeldWatch(_snapshot('first'));
      await env.open(_Backend(held));
      held.send({..._snapshot('held'), 'heldSaves': _heldSaves});
      await _turn();
      replacement = _HeldWatch(_snapshot('second'));
      await env.replace(_Backend(replacement));
    });
    addTearDown(() => tester.runAsync(env.close));
    expect(env.boards.sources.single.live, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttentionView(
            attention: env.attention,
            onDecide: (_, _, {required allow}) {},
            onReview: (_) {},
            actionsFor: (_) => [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('held-saves-kept demo')), findsOneWidget);
    // Opened in place, the kept line says what the live one says: the change, the forge's answer and every try.
    await tester.tap(find.byKey(const Key('held-save-open group-1')));
    await tester.pump();
    final details = find.byKey(const Key('held-save-details group-1'));
    expect(details, findsOneWidget);
    Finder inIt(Finder what) => find.descendant(of: details, matching: what);
    expect(inIt(find.byKey(const Key('held-save-change group-1 0'))), findsOneWidget);
    expect(inIt(find.byKey(const Key('held-save-answer group-1'))), findsOneWidget);
    expect(inIt(find.textContaining('HTTP 502 · Bad gateway')), findsWidgets);
    expect(inIt(find.byKey(const Key('held-save-request group-1'))), findsOneWidget);
    expect(inIt(find.textContaining('req-7f3a')), findsWidgets);
    expect(inIt(find.byKey(const Key('held-save-try group-1 0'))), findsOneWidget);
    expect(
      find.text('The planning board of demo on builder is not read; Resend and Drop return when it is.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('held-save-resend group-1')), findsNothing);
    expect(find.byKey(const Key('held-save-drop group-1')), findsNothing);

    // Read whole again with the save still held, the row acts through the new board.
    await tester.runAsync(() async {
      replacement.send({..._snapshot('third'), 'heldSaves': _heldSaves});
      await _turn();
    });
    await tester.pump();
    expect(find.byKey(const Key('held-save-resend group-1')), findsOneWidget);
    expect(find.byKey(const Key('held-saves-kept demo')), findsNothing);
    expect(find.text('Held saves · demo on builder'), findsOneWidget);
  });

  // Harm: saves the planner still holds leave Needs you while their board is replaced and not read yet, or stay once a
  // whole board holds none.
  test('held saves stay while their board is not read whole, and resolve on a whole board holding none', () async {
    final held = _HeldWatch(_snapshot('first'));
    final env = _Environment();
    await env.open(_Backend(held));
    addTearDown(env.close);
    List<String> heldRows() => [
      for (final row in env.attention.openRows)
        if (row.kind == AttentionKind.heldSaves) row.id,
    ];
    expect(heldRows(), isEmpty, reason: 'a board not read holds no saves to show');
    held.send({
      ..._snapshot('held'),
      'heldSaves': [
        {
          'id': 'group-1',
          'run': false,
          'earlier': false,
          'resendable': true,
          'commands': [
            {'id': 'c1', 'kind': 'SET_FIELDS', 'target': 'item', 'state': 'REFUSED', 'reason': 'Unreachable'},
          ],
        },
      ],
    });
    await _turn();
    expect(heldRows(), ['held saves builder/demo']);
    expect(env.attention.needingSomebody, 1, reason: 'the held saves count as one row');

    final replacement = _HeldWatch(_snapshot('second'));
    await env.replace(_Backend(replacement));
    expect(env.boards.sources.single.live, isFalse);
    expect(heldRows(), ['held saves builder/demo'], reason: 'a board not read yet says nothing of its saves');

    replacement.send(_snapshot('third'));
    await _turn();
    expect(env.boards.sources.single.live, isTrue);
    expect(heldRows(), isEmpty);
    expect(
      env.attention.recentlyResolved.map((each) => each.row.id),
      contains('held saves builder/demo'),
      reason: 'a whole board holding none resolves them',
    );
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
            'role': authorRole,
            'readLanded': <String>[],
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
            'role': authorRole,
            'readLanded': <String>[],
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
    held.send(_snapshot('resumed'));
    await _turn();
    expect(env.settings.readingsPutAway, isEmpty, reason: 'the board, read whole, no longer says it');

    held.send(_snapshot('stopped again', stopped: true));
    await _turn();
    expect(env.planningRows, ['reading builder/demo/item'], reason: 'its next stop is said');
  });

  // Harm: a row the person marked seen still counts on the planning board and keeps its story card saying needs you,
  // so the board sends them back to what they already read; or a row seen hides its next stop or end.
  test("a row seen leaves the boards' Needs you and its story's card until it is said again", () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    PlanStory story() => env.boards.sources.single.stories.single;
    expect([for (final each in env.boards.needsYou) each.id], ['reading builder/demo/item']);
    expect(env.boards.sources.single.attentionSeen(story()), isFalse);

    env.attention.readingSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.boards.needsYou, isEmpty, reason: 'the reading was put away');
    expect(env.boards.sources.single.attentionSeen(story()), isTrue, reason: 'its card no longer says needs you');
    expect(env.settings.readingsPutAway, hasLength(1), reason: 'the mark stays while the board says the reading');

    planning.push('demo', _snapshot('moved', stopped: true, state: 'Review'));
    await _turn();
    expect([for (final each in env.boards.needsYou) each.id], ['reading builder/demo/item'], reason: 'state changed');
    expect(env.boards.sources.single.attentionSeen(story()), isFalse);

    StoryWorkStatus endedAt(String at) => StoryWorkStatus.from({
      'work': {
        'atWork': false,
        'tasks': [
          {
            'task': 'main',
            'role': authorRole,
            'readLanded': <String>[],
            'ended': {'at': at, 'outcome': 'BLOCKED', 'why': 'Needs a repository key.', 'answer': ''},
          },
        ],
      },
    });
    planning.status = endedAt('2026-11-10T09:00:00Z');
    planning.push('demo', _snapshot('ended', working: true));
    await _turn();
    expect([for (final each in env.boards.needsYou) each.id], ['story ended builder/demo/story']);
    env.attention.storyEndSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.boards.needsYou, isEmpty, reason: "the story's end was seen");
    expect(env.settings.endedPutAway, hasLength(1), reason: 'the mark stays while the board says the end');

    planning.status = endedAt('2026-11-10T10:00:00Z');
    planning.push('demo', _snapshot('ended again', working: true));
    await _turn();
    expect(
      [for (final each in env.boards.needsYou) each.id],
      ['story ended builder/demo/story'],
      reason: 'a later end',
    );
  });

  /// Puts away the one stopped reading [env] shows.
  Future<void> putAway(_Environment env) async {
    env.attention.readingSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
  }

  StoryWorkStatus work({List<Map<String, Object>> tasks = const [], List<Map<String, Object>> issues = const []}) =>
      StoryWorkStatus.from({
        'work': {'atWork': false, 'tasks': tasks, 'issues': issues},
      });

  List<String> boardRows(PlanningBoards boards) => [for (final each in boards.needsYou) each.id];

  // Harm: a reading put away hides the end of its issue's task that comes later, so the person never hears of it.
  test("a reading put away still says a later end of its issue's task", () async {
    final planning = _Planning(_snapshot('initial', stopped: true, working: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    await putAway(env);
    expect(boardRows(env.boards), isEmpty, reason: 'put away');

    planning.status = work(
      tasks: [
        {
          'task': 'reader',
          'role': authorRole,
          'readLanded': <String>[],
          'issues': ['item'],
          'ended': {'at': '2026-11-10T09:00:00Z', 'outcome': 'BLOCKED', 'why': 'Needs a key.', 'answer': ''},
        },
      ],
    );
    planning.push('demo', _snapshot('ended', stopped: true, working: true));
    await _turn();
    expect(boardRows(env.boards), contains('reading builder/demo/item'), reason: "its task's end is said");
    expect(env.planningRows, contains('reading builder/demo/item'), reason: 'and counted under Needs you');
  });

  // Harm: an issue row whose task ended, marked seen, still counts on the boards and keeps its story card saying needs
  // you; or its mark is one the boards cannot ask, so it hides nothing there.
  test("an issue row whose task ended, marked seen, leaves the boards as its story's end", () async {
    final planning = _Planning(_snapshot('initial', stopped: true, working: true))
      ..status = work(
        tasks: [
          {
            'task': 'reader',
            'role': authorRole,
            'readLanded': <String>[],
            'issues': ['item'],
            'ended': {'at': '2026-11-10T09:00:00Z', 'outcome': 'BLOCKED', 'why': 'Needs a key.', 'answer': ''},
          },
        ],
      );
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(boardRows(env.boards), ['story ended builder/demo/story', 'reading builder/demo/item']);

    env.attention.storyEndSeen(env.attention.openRows.firstWhere((row) => row.id == 'reading builder/demo/item'));
    await _turn();
    expect(env.settings.endedPutAway, {'story ended builder/demo/story at 2026-11-10T09:00:00Z'});
    expect(boardRows(env.boards), isEmpty, reason: 'the end seen covers the story and its issue that ended then');
    expect(env.planningRows, isEmpty);
    expect(env.boards.sources.single.attentionSeen(env.boards.sources.single.stories.single), isTrue);
  });

  // Harm: a story's end with no time, seen in this window only, keeps counting on the boards.
  test("a story's end with no time seen leaves the boards for this window's life", () async {
    final planning = _Planning(_snapshot('initial', working: true))
      ..status = work(
        tasks: [
          {
            'task': 'main',
            'role': authorRole,
            'readLanded': <String>[],
            'ended': {'at': '', 'outcome': 'BLOCKED', 'why': 'Needs a key.', 'answer': ''},
          },
        ],
      );
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(boardRows(env.boards), ['story ended builder/demo/story']);

    env.attention.storyEndSeen(env.attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.settings.endedPutAway, isEmpty, reason: 'a mark with no time is kept for this window only');
    expect(boardRows(env.boards), isEmpty, reason: 'seen');
  });

  // Harm: a reading put away before the settings were read keeps counting on the boards.
  test('a reading put away before the settings were read leaves the boards', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    final unread = Settings(env.store);
    final attention = Attention(env.machines, unread);
    final boards = PlanningBoards(env.client, seen: attention.seen);
    attention.planning = boards;
    addTearDown(() {
      attention.dispose();
      boards.dispose();
      unread.dispose();
    });
    await _turn();
    expect(boardRows(boards), ['reading builder/demo/item']);

    attention.readingSeen(attention.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(unread.readingsPutAway, isEmpty, reason: 'settings not read are not written');
    expect(boardRows(boards), isEmpty, reason: 'put away');
  });

  // Harm: a reading put away hides the issue raised again for another reason.
  test("a reading put away is said again once its reason changes", () async {
    final planning = _Planning(_snapshot('initial', working: true))
      ..status = work(
        issues: [
          {'issue': 'item', 'reason': 'STOPPED'},
        ],
      );
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    expect(boardRows(env.boards), ['reading builder/demo/item']);
    await putAway(env);
    expect(boardRows(env.boards), isEmpty, reason: 'put away');

    planning.status = work(
      issues: [
        {'issue': 'item', 'reason': 'SAVE_REFUSED'},
      ],
    );
    planning.push('demo', _snapshot('another reason', working: true));
    await _turn();
    expect(boardRows(env.boards), ['reading builder/demo/item'], reason: 'its reason changed');
    expect(env.planningRows, ['reading builder/demo/item']);
  });

  // Harm: a stop put away hid the same issue's later stop, after its state had moved on and come back while the issue
  // stayed raised.
  test('a stopped reading put away is said again once its state moves on and comes back', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    await putAway(env);
    expect(env.planningRows, isEmpty);

    planning.push('demo', _snapshot('moved', stopped: true, state: 'Review'));
    await _turn();
    expect(env.planningRows, ['reading builder/demo/item'], reason: 'its state moved on');
    planning.push('demo', _snapshot('back', stopped: true));
    await _turn();
    expect(env.planningRows, ['reading builder/demo/item'], reason: 'its state came back: a stop to be said again');
  });

  // Harm: a board whose stories' work could not be read taken as one that no longer says the issue, so what was put
  // away came back at the next read.
  test("a stopped reading put away stays put away while its board's work cannot be read", () async {
    final planning = _Planning(_snapshot('initial', stopped: true, working: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    await putAway(env);

    planning.workError = mockRefusal('org.fuin.porelo.Tasks1.Refused', {'detail': 'Work cannot be read.'});
    planning.push('demo', _snapshot('unread work', working: true));
    await _turn();
    expect(env.settings.readingsPutAway, hasLength(1), reason: "a story whose work cannot be read says nothing");

    planning.workError = null;
    planning.push('demo', _snapshot('stopped again', stopped: true, working: true));
    await _turn();
    expect(env.planningRows, isEmpty, reason: 'the same stop stays put away');
  });

  // Harm: marks of machines and projects the window no longer has kept in the settings for good.
  test('a stopped reading put away is forgotten once its machine or its project is gone', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    await putAway(env);
    final mine = env.settings.readingsPutAway.single;
    PlanningPutAway on(String machine, String project) =>
        PlanningPutAway(machine: machine, project: project, issue: 'item', reason: mine.reason, state: mine.state);
    await env.settings.setReadingsPutAway({mine, on('elsewhere', 'demo'), on('builder', 'retired')});
    await _turn();
    expect(env.settings.readingsPutAway, contains(on('elsewhere', 'demo')), reason: 'the machines are not read yet');

    await env.settings.machines();
    await env.settings.setReadingsPutAway({...env.settings.readingsPutAway});
    await _turn();

    expect(env.settings.readingsPutAway, {mine});
  });

  // Harm: a stopped reading put away before the settings were read came back at the next start.
  test('a stopped reading put away before the settings were read is kept in them once they are', () async {
    final planning = _Planning(_snapshot('initial', stopped: true));
    final env = _Environment();
    await env.open(_Backend(planning));
    addTearDown(env.close);
    final unread = Settings(env.store);
    final early = Attention(env.machines, unread)..planning = env.boards;
    addTearDown(() {
      early.dispose();
      unread.dispose();
    });
    await _turn();
    early.readingSeen(early.openRows.firstWhere((row) => row.kind == AttentionKind.planning));
    await _turn();
    expect(env.rowsOf(early), isEmpty);

    await unread.load();
    await _turn();

    final reloaded = Settings(env.store);
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.readingsPutAway.map((each) => each.issue), ['item'], reason: 'kept past a restart');
  });
}
