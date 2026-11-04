import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/client/models.dart' show ServiceInfo;
import 'package:porelo_frontend/src/wire/varlink_exception.dart' show VarlinkDisconnected;
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../features/support/world.dart' show FakeBackend;

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// Tunnels that refuse, as a machine closing connections before login does.
class _RefusedTunnels extends Tunnels {
  var raises = 0;
  TunnelState stateNow = TunnelState.down;
  Completer<void>? raising;
  final _tunnels = <String, Tunnel>{};

  @override
  bool manages(Machine machine) => true;

  @override
  Tunnel? of(Machine machine) => machine.name != 'alpha'
      ? null
      : (_tunnels.putIfAbsent(machine.name, () => Tunnel(machine))
          ..state = stateNow
          ..problem = 'Connection closed by 203.0.113.9 port 22');

  @override
  Future<bool> raiseFor(Machine machine) async {
    if (machine.name == 'alpha') raises++;
    return false;
  }

  @override
  Future<void> raiseAgainIfItDropped(Machine machine) async {
    if (machine.name != 'alpha') return;
    raises++;
    await raising?.future;
  }
}

class _Refusing extends FakeBackend {
  _Refusing() : super(const []);

  var opens = 0;

  @override
  Future<ServiceInfo> open() async {
    opens++;
    throw const VarlinkDisconnected('Connection closed by 203.0.113.9 port 22');
  }
}

Machine _card() => Machine.fromHostCard(
  HostCardSsh(
    name: 'alpha',
    address: 'alpha.example.org',
    sshPort: 2222,
    hostKey: _key,
    login: 'alice',
    publicKey: _key,
    webPort: 18080,
    gitPort: 18081,
    matrixPort: 18082,
  ),
  socketPath: '/tmp/porelo-hold-test-d',
  sshConfig: '/tmp/porelo-hold-test/alpha.conf',
);

void main() {
  late DateTime now;
  late _RefusedTunnels tunnels;
  late _Refusing backend;
  final firstWait = Machines.firstRaiseWait + const Duration(seconds: 1);

  Machines machinesWith({bool relays = false}) {
    final machines = Machines(
      Settings(MemorySettingsStore()),
      reach: (machine) => machine.name == 'alpha' ? backend : FakeBackend(const []),
      tunnels: tunnels,
      now: () => now,
      retryAfter: const Duration(milliseconds: 5),
      relaysBySsh: (machine) => relays && machine.name == 'alpha',
    );
    addTearDown(machines.dispose);
    return machines;
  }

  Future<void> aWhile() => Future<void>.delayed(const Duration(milliseconds: 80));

  /// Waits for a try that should come, however loaded this computer is, then long enough to see another.
  Future<void> reaches(int raises) async {
    final by = DateTime.now().add(const Duration(seconds: 20));
    while (tunnels.raises < raises && DateTime.now().isBefore(by)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await aWhile();
  }

  setUp(() {
    now = DateTime.utc(2026, 11, 4);
    tunnels = _RefusedTunnels();
    backend = _Refusing();
  });

  // Harm: sshd refuses an address that keeps connecting without logging in, and a window asking every
  // two seconds keeps it refused for as long as it stays open.
  test('a machine that refuses is tried again after longer and longer, and at once when asked', () async {
    final machines = machinesWith();
    final machine = _card();
    await machines.add(machine);
    await reaches(1);
    expect(tunnels.raises, 1, reason: 'one try, then it waits');
    expect(machines.of(machine).status, contains('within five minutes'), reason: 'why it does not come back at once');

    now = now.add(firstWait);
    await reaches(2);
    expect(tunnels.raises, 2);

    now = now.add(firstWait);
    await reaches(2);
    expect(tunnels.raises, 2, reason: 'the second wait is longer');

    await machines.of(machine).connect();
    expect(tunnels.raises, 3, reason: 'what a person presses goes at once');
  });

  // Harm: a press on a forward without a card is held, as its raise is the listener's.
  test('a forward with no card goes at once when asked, and waits when not', () async {
    final machines = machinesWith();
    const machine = Machine(name: 'alpha', socketPath: '/tmp/porelo-hold-test-f', host: 'alice@alpha.example.org');
    await machines.add(machine);
    await reaches(1);
    expect(tunnels.raises, 1, reason: 'one raise for the opening');
    await machines.of(machine).connect();
    await reaches(2);
    expect(tunnels.raises, 2, reason: 'the press goes though it is held');
    await reaches(2);
    expect(tunnels.raises, 2, reason: 'and only once');
  });

  // Harm: an agent's key comes back and the machine still waits out an old failure.
  test('waiting for a key ends the wait of an earlier failure', () async {
    final machines = machinesWith();
    final machine = _card();
    await machines.add(machine);
    await reaches(1);
    expect(tunnels.raises, 1);
    tunnels.stateNow = TunnelState.waitingForKey;
    await machines.of(machine).connect();
    final during = tunnels.raises;
    await aWhile();
    expect(tunnels.raises, greaterThan(during), reason: 'no clock has moved, and it is not held');
  });

  // Harm: a new machine under an old name inherits how long the old one had to wait.
  test('a machine forgotten and added again starts its waits anew', () async {
    final machines = machinesWith();
    final machine = _card();
    await machines.add(machine);
    await aWhile();
    now = now.add(firstWait);
    await reaches(2);
    expect(tunnels.raises, 2, reason: 'its wait is now the second, a minute');
    await machines.forget(machine);
    await machines.add(machine);
    await reaches(3);
    expect(tunnels.raises, 3);
    now = now.add(firstWait);
    await reaches(4);
    expect(tunnels.raises, 4, reason: 'half a minute again, not two');
  });

  // Harm: the timer starts a second connection while one is on its way, and its failure is not yet known.
  test('nothing else tries while a raise of its own is under way', () async {
    final machines = machinesWith();
    final machine = _card();
    await machines.add(machine);
    await reaches(1);
    expect(tunnels.raises, 1);
    now = now.add(firstWait);
    tunnels.raising = Completer<void>();
    final raising = machines.raiseAgainIfNeeded(machine);
    await reaches(2);
    expect(tunnels.raises, 2, reason: 'only the raise under way');
    tunnels.raising!.complete();
    await raising;
  });

  // Harm: on Windows the relay is itself an ssh connection, with no tunnel to hold it.
  test('a relay over ssh waits too, and asks again at once when asked', () async {
    final machines = machinesWith(relays: true);
    const machine = Machine(name: 'alpha', socketPath: '/tmp/porelo-hold-test-r', host: 'alice@alpha.example.org');
    tunnels.stateNow = TunnelState.down;
    await machines.add(machine);
    await aWhile();
    final first = backend.opens;
    expect(first, lessThanOrEqualTo(2), reason: 'the opening, and one try before the wait counts');
    await aWhile();
    expect(backend.opens, first, reason: 'it waits');
    now = now.add(firstWait);
    await aWhile();
    expect(backend.opens, first + 1);
    await machines.of(machine).connect();
    expect(backend.opens, first + 2);
  });
}
