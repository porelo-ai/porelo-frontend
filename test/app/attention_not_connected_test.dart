import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

class _Silent extends FakeBackend {
  _Silent() : super(const []);

  @override
  Future<ServiceInfo> open() => throw const VarlinkDisconnected('nothing there');
}

void main() {
  // Harm: a person who just prepared a host reads that it has gone silent, and goes looking for a fault, when all
  // that is left is to connect. A host that did answer must still read as not answering when it goes away.
  test('a host that never answered is not called silent, and one that did is not excused', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(
      settings,
      reach: (machine) => machine.name == 'orchard' ? _Silent() : FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    final attention = Attention(machines);
    addTearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });
    const prepared = Machine(name: 'orchard', socketPath: '/tmp/orchard.sock', kind: 'host');
    const answering = Machine(name: 'apple', socketPath: '/tmp/apple.sock', kind: 'host');
    await machines.add(prepared);
    await machines.add(answering);
    await machines.of(machines.all.firstWhere((each) => each.name == 'orchard')).untilAsked();
    await machines.of(machines.all.firstWhere((each) => each.name == 'apple')).untilAsked();
    expect(attention.notConnectedYet(prepared), isTrue);
    expect(attention.notConnectedYet(answering), isFalse);
  });
}
