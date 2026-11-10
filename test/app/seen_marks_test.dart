import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

/// A machine with the usual work on it, watched by an [Attention] keeping its marks in [store].
class _Window {
  _Window(this.store, {List<Task>? tasks, this.now}) : backend = FakeBackend(tasks ?? World.work)..nodeId = 'here';

  final MemorySettingsStore store;
  final FakeBackend backend;
  final DateTime Function()? now;
  late final Settings settings = Settings(store);
  late final Machines machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
  late Attention attention;

  String get machine => machines.current.name;

  Future<void> open({bool load = true, Map<String, Object?> stored = const <String, Object?>{}}) async {
    machines;
    await store.write(<String, Object?>{...await store.read(), ...stored});
    if (load) await settings.load();
    await machines.of(machines.current).untilAsked();
    attention = Attention(machines, settings, null, now);
    await pumpEventQueue();
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });
  }

  List<RanOutQuestion> get ranOutRows => [
    for (final row in attention.openRows)
      if (row.kind == AttentionKind.ranOut) row.value as RanOutQuestion,
  ];
}

/// The same question a second time, carrying that it ran out at [at].
Prompt _ranOut(Prompt asked, String at) => Prompt.from(<String, dynamic>{
  'task': asked.task,
  'key': asked.key,
  'destination': asked.destination,
  'protocol': asked.protocol,
  'port': asked.port,
  'at': at,
  'prefix': '',
  'verdict': 'timeout',
});

/// [name] from [tasks], its agent ended as given.
List<Task> _ended(String name, {int unpushed = 0, List<Task>? tasks}) => <Task>[
  for (final task in tasks ?? World.work)
    if (task.name != name)
      task
    else
      Task.from(<String, dynamic>{
        ...wire(task),
        'activity': 'ENDED',
        'agentEnded': <String, dynamic>{
          'at': '2026-11-10T09:00:00Z',
          // Finished with nothing left outside the gate needs nobody; stopped before its end does.
          'finished': unpushed > 0,
          'error': unpushed > 0 ? '' : 'it stopped',
          'source': '',
          'unpushed': unpushed,
        },
      }),
];

/// [name] from [tasks], its agent stopped before its end at no time a machine said, nor when its state began.
List<Task> _endedAtNoTime(String name, {List<Task>? tasks}) => <Task>[
  for (final task in tasks ?? World.work)
    if (task.name != name)
      task
    else
      Task.from(<String, dynamic>{
        ...wire(task),
        'activity': 'ENDED',
        'since': '',
        'agentEnded': <String, dynamic>{
          'at': '',
          'finished': false,
          'error': 'it stopped',
          'source': '',
          'unpushed': 0,
        },
      }),
];

void main() {
  final asked = World.blocked('api.example.test:443');

  // Harm: a question that runs out a second time is hidden by the mark of the first, and the work stays blocked unsaid.
  test('a question that ran out again after one was seen is said again', () async {
    final window = _Window(MemorySettingsStore());
    await window.open();
    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T09:00:00Z'));
    await pumpEventQueue();
    expect(window.ranOutRows, hasLength(1));
    window.attention.ranOutSeen(window.ranOutRows.single);
    await pumpEventQueue();
    expect(window.ranOutRows, isEmpty);

    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T10:00:00Z'));
    await pumpEventQueue();
    expect(window.ranOutRows, hasLength(1), reason: 'another occurrence of the same question');
  });

  // Harm: a mark an older build kept, which says no occurrence, hides a question that runs out now.
  test('a seen mark of an older build hides no question that runs out', () async {
    final window = _Window(MemorySettingsStore());
    await window.open(
      stored: <String, Object?>{
        'ranOut': <Object>[
          <String, Object>{
            'id': 'this machine/${asked.identity}',
            'machine': 'this machine',
            'task': asked.task,
            'shown': asked.shown,
            'seen': true,
          },
        ],
      },
    );
    expect(window.machine, 'this machine', reason: 'the mark names the machine the window watches');
    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T09:00:00Z'));
    await pumpEventQueue();
    expect(window.ranOutRows, hasLength(1));
  });

  // Harm: marks of a stream that never says a question is gone pile up in the settings for ever.
  test('a seen mark of a question that ran out is kept a week, then dropped', () async {
    var now = DateTime.utc(2026, 11, 10, 9);
    final window = _Window(MemorySettingsStore(), now: () => now);
    await window.open();
    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T09:00:00Z'));
    await pumpEventQueue();
    window.attention.ranOutSeen(window.ranOutRows.single);
    await pumpEventQueue();
    List<RanOutQuestion> seen() => [
      for (final each in window.settings.ranOut)
        if (each.seen) each,
    ];

    now = now.add(const Duration(days: 6));
    window.backend.publish(window.backend.tasksNow);
    await pumpEventQueue();
    expect(seen(), hasLength(1), reason: 'within the week');

    now = now.add(const Duration(days: 2));
    window.backend.publish(window.backend.tasksNow);
    await pumpEventQueue();
    expect(seen(), isEmpty, reason: 'past the week');
  });

  // Harm: changed files that never reached the gate are put away as seen, and go with the task when it is removed.
  test('an end with files that never reached the gate cannot be put away, nor hidden by a mark', () async {
    const name = 'porelo-checkout-shell';
    final window = _Window(MemorySettingsStore(), tasks: _ended(name, unpushed: 2));
    await window.open();
    Iterable<Tile> ends() => window.attention.causes.where((each) => each.demand == Demand.ended);
    expect(ends(), hasLength(1));
    window.attention.putAwayTheEnd(ends().single);
    await pumpEventQueue();
    expect(ends(), hasLength(1), reason: 'something is still owed');

    final marked = _Window(MemorySettingsStore(), tasks: _ended(name, unpushed: 2));
    await marked.open(
      stored: <String, Object?>{
        'endedPutAway': <String>['this machine/$name/2026-11-10T09:00:00Z/true/0/2'],
      },
    );
    expect(marked.attention.causes.where((each) => each.demand == Demand.ended), hasLength(1));
  });

  // Harm: a mark set before the settings were read replaces every mark stored, and ends seen long ago come back.
  test('a mark set before the settings are read keeps every mark stored', () async {
    const stored = 'elsewhere/porelo-billing-shell/2026-10-01T00:00:00Z/true/0/0';
    final store = MemorySettingsStore(<String, Object?>{
      'endedPutAway': <String>[stored],
    });
    final window = _Window(store, tasks: _ended('porelo-checkout-shell'));
    await window.open(load: false);
    window.attention.putAwayTheEnd(window.attention.causes.firstWhere((each) => each.demand == Demand.ended));
    await pumpEventQueue();
    expect(window.attention.causes.where((each) => each.demand == Demand.ended), isEmpty, reason: 'seen now');
    await window.settings.load();
    expect(window.settings.endedPutAway, contains(stored));
  });
  // Harm: a question seen once comes back a week later as never seen, because its machine said it again meanwhile.
  test('a seen question its machine says again stays seen past the week', () async {
    var now = DateTime.utc(2026, 11, 10, 9);
    final window = _Window(MemorySettingsStore(), now: () => now);
    await window.open();
    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T09:00:00Z'));
    await pumpEventQueue();
    window.attention.ranOutSeen(window.ranOutRows.single);
    await pumpEventQueue();

    now = now.add(const Duration(days: 1));
    window.backend.asking
      ..add(asked)
      ..add(_ranOut(asked, '2026-11-10T09:00:00Z'));
    await pumpEventQueue();
    expect(window.ranOutRows, isEmpty, reason: 'the same occurrence, said again on a new connection');

    now = now.add(const Duration(days: 7));
    window.backend.publish(window.backend.tasksNow);
    await pumpEventQueue();
    expect(window.ranOutRows, isEmpty, reason: 'past the week');
  });

  // Harm: work retrying a blocked connection fills Needs you and the settings with one row per time it ran out.
  test('a question that runs out again before anybody looked is one row', () async {
    final window = _Window(MemorySettingsStore());
    await window.open();
    for (final at in ['2026-11-10T09:00:00Z', '2026-11-10T09:05:00Z', '2026-11-10T09:10:00Z']) {
      window.backend.asking
        ..add(asked)
        ..add(_ranOut(asked, at));
      await pumpEventQueue();
    }
    expect(window.ranOutRows.map((each) => each.id), ['this machine/${asked.identity} at 2026-11-10T09:10:00Z']);
  });

  // Harm: an end with no time, seen once, hides every later end of the same work for as long as the window is open.
  test('an end with no time is said again when the work ends again', () async {
    const name = 'porelo-checkout-shell';
    final window = _Window(MemorySettingsStore(), tasks: _endedAtNoTime(name));
    await window.open();
    Iterable<Tile> ends() => window.attention.causes.where((each) => each.demand == Demand.ended);
    window.attention.putAwayTheEnd(ends().single);
    await pumpEventQueue();
    expect(ends(), isEmpty, reason: 'seen');

    window.backend.publish(World.work);
    await pumpEventQueue();
    window.backend.publish(_endedAtNoTime(name));
    await pumpEventQueue();
    expect(ends(), hasLength(1), reason: 'it ended again');
  });

  // Harm: a mark an older build kept for an end with no time hides every end of that work with no time.
  test("an older build's mark of an end with no time hides no end", () async {
    const name = 'porelo-checkout-shell';
    final window = _Window(MemorySettingsStore(), tasks: _endedAtNoTime(name));
    await window.open(
      stored: <String, Object?>{
        'endedPutAway': <String>['this machine/$name//false/null/0'],
      },
    );
    expect(window.attention.causes.where((each) => each.demand == Demand.ended), hasLength(1));
  });

  // Harm: where no machines were ever stored, the notice of machines set aside, once seen, is kept for ever and hides
  // the next.
  test('a seen notice of machines set aside goes where no machines are stored', () async {
    final window = _Window(MemorySettingsStore());
    await window.open(
      stored: <String, Object?>{
        'seenSilent': <String>['set aside: one machine set aside'],
      },
    );
    await window.machines.load();
    await pumpEventQueue();
    expect(window.settings.machinesRead, isTrue);
    expect(window.settings.seenSilent, isNot(contains('set aside: one machine set aside')));
  });
}
