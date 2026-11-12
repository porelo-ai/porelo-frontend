import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/planning_reports.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a refused removal of a handed-in discussion asks the person about a removal they never asked for, and the
  // window never says the discussion could not be removed.
  test('a refused removal of a handed-in discussion is said by the hand-in, not raised to the person', () async {
    final backend = FakeBackend(const []);
    final machines = Machines(Settings(MemorySettingsStore()), reach: (_) => backend, tunnels: FakeTunnels());
    addTearDown(machines.dispose);
    backend.nextRemove = Removed.from(const <String, dynamic>{
      'outcome': 'HOLDS_WORK',
      'work': 'two commits',
      'rescuedRef': '',
      'removed': false,
      'discarded': 0,
    });
    final machine = machines.current;

    await expectLater(removeHandedDiscussion(machines, machine.name, 'porelo-demo-discussion'), throwsA(anything));
    expect(machines.of(machine).refusal, isNull);
  });
}
