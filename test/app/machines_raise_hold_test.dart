import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../features/support/world.dart' show FakeBackend;

class _RefusedTunnels extends Tunnels {
  var raises = 0;

  @override
  bool manages(Machine machine) => true;

  @override
  Future<bool> raiseFor(Machine machine) async {
    if (machine.name == 'alpha') raises++;
    return false;
  }

  @override
  Future<void> raiseAgainIfItDropped(Machine machine) async {
    if (machine.name == 'alpha') raises++;
  }
}

void main() {
  const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  // Harm: sshd refuses an address that keeps connecting without logging in, and a window asking every
  // two seconds keeps it refused for as long as it stays open.
  test('a machine that refuses is tried again after longer and longer, and at once when asked', () async {
    var now = DateTime.utc(2026, 11, 4);
    final tunnels = _RefusedTunnels();
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(
      settings,
      reach: (_) => FakeBackend(const []),
      tunnels: tunnels,
      now: () => now,
      retryAfter: const Duration(milliseconds: 5),
    );
    addTearDown(machines.dispose);
    final machine = Machine.fromHostCard(
      HostCardSsh(
        name: 'alpha',
        address: 'alpha.example.org',
        sshPort: 2222,
        hostKey: key,
        login: 'alice',
        publicKey: key,
        webPort: 18080,
        gitPort: 18081,
        matrixPort: 18082,
      ),
      socketPath: '/tmp/porelo-hold-test-d',
      sshConfig: '/tmp/porelo-hold-test/alpha.conf',
    );
    await machines.add(machine);
    Future<int> triesAfterAWhile() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return tunnels.raises;
    }

    final first = await triesAfterAWhile();
    expect(first, 1, reason: 'one try, then it waits');

    now = now.add(Machines.firstRaiseWait + const Duration(seconds: 1));
    expect(await triesAfterAWhile(), 2);

    now = now.add(Machines.firstRaiseWait + const Duration(seconds: 1));
    expect(await triesAfterAWhile(), 2, reason: 'the second wait is longer');

    expect(machines.of(machine).status, contains('within five minutes'), reason: 'why it does not come back at once');
    await machines.of(machine).connect();
    expect(tunnels.raises, 3, reason: 'what a person presses goes at once');
  });
}
