import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

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

  // Harm: two rows for one machine, the one that says it cannot be reached sending a person to the
  // connection when what it waits for is the token.
  test('a machine that waits for its token has that row, and not one for its connection', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(
      settings,
      reach: (machine) => machine.hostCard != null ? _Silent() : FakeBackend(const []),
      tunnels: FakeTunnels(),
    );
    final attention = Attention(machines);
    final connections = FixtureConnections(['build'])..waiting.add('build');
    final organization = Organization(FixtureOrganization(organizationFor('hana')));
    addTearDown(() {
      attention.dispose();
      organization.dispose();
      connections.dispose();
      machines.dispose();
      settings.dispose();
    });
    await organization.refresh();
    attention.watchTokens(connections, organization);
    await machines.add(
      Machine.fromHostCard(
        HostCardSsh(
          name: 'build',
          address: 'build.example.org',
          sshPort: 22,
          hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          login: 'hana',
          publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        ),
        socketPath: '/tmp/build.sock',
        sshConfig: '/tmp/build.config',
      ),
    );
    for (final machine in machines.all) {
      await machines.of(machine).untilAsked();
    }
    expect([for (final row in attention.openRows) row.kind], [AttentionKind.token]);

    connections.waiting.clear();
    connections.notifyListeners();
    expect(attention.openRows.where((row) => row.kind == AttentionKind.token), isEmpty);
  });
}
