import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

/// The usual work on one machine, watched by an [Attention] with its settings read.
Future<({FakeBackend backend, Attention attention})> _open() async {
  final backend = FakeBackend(World.work)..nodeId = 'here';
  final settings = Settings(MemorySettingsStore());
  await settings.load();
  final machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
  await machines.of(machines.current).untilAsked();
  final attention = Attention(machines, settings);
  await pumpEventQueue();
  addTearDown(() {
    attention.dispose();
    machines.dispose();
    settings.dispose();
  });
  return (backend: backend, attention: attention);
}

/// [name] said to wait on a person since [since], as `Watch` says it.
List<Task> _waiting(List<Task> tasks, String name, String since) => <Task>[
  for (final task in tasks)
    if (task.name != name)
      task
    else
      Task.from(<String, dynamic>{
        ...wire(task),
        'activity': 'WAITING',
        'waitingFor': 'api.example.test:443',
        'since': since,
      }),
];

void main() {
  const name = 'porelo-checkout-shell';
  final asked = World.blocked('api.example.test:443');

  // Harm: a question that ran out, and stays blocked, reads as resolved beside the row saying it ran out.
  test('a question that ran out is not said to be resolved', () async {
    final window = await _open();
    window.backend.asking.add(asked);
    await pumpEventQueue();
    window.backend.asking.add(World.settled(asked, 'timeout'));
    await pumpEventQueue();
    expect(window.attention.openRows.where((row) => row.kind == AttentionKind.ranOut), hasLength(1));
    expect(window.attention.recentlyResolved.map((each) => each.row.id), isNot(contains(startsWith('question '))));
  });

  // Harm: the question a waiting task asks reads as a wait resolved, while it is still open.
  test('a wait that becomes its question is not said to be resolved', () async {
    final window = await _open();
    window.backend.publish(_waiting(window.backend.tasksNow, name, '2026-09-07T14:59:00Z'));
    await pumpEventQueue();
    expect(window.attention.openRows.map((row) => row.id), contains(startsWith('waits ')));
    window.backend.asking.add(asked);
    await pumpEventQueue();
    expect(window.attention.openRows.map((row) => row.id), contains(startsWith('question ')));
    expect(window.attention.recentlyResolved.map((each) => each.row.id), isNot(contains(startsWith('waits '))));
  });

  // Harm: a question answered a moment ago comes back as a wait that asks the person again.
  test('a question answered while the list still says the task waits asks nothing again', () async {
    final window = await _open();
    window.backend.publish(_waiting(window.backend.tasksNow, name, '2026-09-07T14:59:00Z'));
    window.backend.asking.add(asked);
    await pumpEventQueue();
    window.backend.asking.add(World.settled(asked, 'allow'));
    await pumpEventQueue();
    expect(window.attention.openRows.map((row) => row.id), isNot(contains(startsWith('waits '))));
    expect(window.attention.openRows.map((row) => row.id), isNot(contains(startsWith('question '))));
  });
}
