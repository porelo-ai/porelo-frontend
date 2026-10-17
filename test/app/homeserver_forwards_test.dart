import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/homeserver_forwards.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

class _Forward implements HeldForward {
  _Forward(this.closed);

  final void Function() closed;

  @override
  Future<void> close() async => closed();
}

void main() {
  const vm = Machine(
    name: 'vm',
    socketPath: '/tmp/vm.sock',
    host: 'alice@vm',
    remoteSocket: '/run/user/1000/porelo/porelod.sock',
  );

  Future<Machines> machinesWithVm(Settings settings) async {
    final machines = Machines(settings, reach: (machine) => FakeBackend(const <Task>[]), tunnels: FakeTunnels());
    await machines.add(vm);
    return machines;
  }

  // Walk 10: nheko lost its server when the Messages dialog closed. What was joined
  // before is reachable again when the window starts, at the same port.
  test('a homeserver joined before is forwarded again when the window starts, at the same port', () async {
    final settings = Settings(MemorySettingsStore());
    await settings.rememberHomeserver('vm', 'checkout', 8010);
    final raised = <int>[];
    final forwards = HomeserverForwards(
      settings,
      raise: (machine, port) async {
        raised.add(port);
        return _Forward(() {});
      },
      answers: (port) async => true,
    );
    final machines = await machinesWithVm(settings);

    await forwards.restore(machines);

    expect(raised, <int>[8010]);
    expect(forwards.portOf(vm, 'checkout'), 8010);
    forwards.dispose();
    machines.dispose();
  });

  test('a forward that cannot be raised says why, and is kept to try again', () async {
    final settings = Settings(MemorySettingsStore());
    final forwards = HomeserverForwards(
      settings,
      raise: (machine, port) async => throw const ForwardRefused('Port 8010 is already in use on this computer.'),
      answers: (port) async => false,
    );

    await forwards.hold(vm, 'checkout', 8010);

    expect(forwards.portOf(vm, 'checkout'), isNull);
    expect(forwards.problemOf(vm, 'checkout'), contains('already in use'));
    expect(settings.homeservers.single.port, 8010);
    forwards.dispose();
  });

  test('one held forward per project: joining again replaces what was kept, never doubles it', () async {
    final settings = Settings(MemorySettingsStore());
    final closed = <int>[];
    final forwards = HomeserverForwards(
      settings,
      raise: (machine, port) async => _Forward(() => closed.add(port)),
      answers: (port) async => false,
    );

    await forwards.hold(vm, 'checkout', 8010);
    await forwards.hold(vm, 'checkout', 8010);

    expect(settings.homeservers, hasLength(1));
    expect(closed, <int>[8010], reason: 'the first one, no longer answering, was let go before the second');
    forwards.dispose();
  });

  // The harm: an ssh forward that came up after the window closed its forwards was kept by nobody,
  // a process left holding a port.
  test('a forward that comes up after the forwards are closed is taken down at once', () async {
    final settings = Settings(MemorySettingsStore());
    final raising = Completer<HeldForward>();
    var closed = 0;
    final forwards = HomeserverForwards(
      settings,
      raise: (machine, port) => raising.future,
      answers: (port) async => true,
    );

    final held = forwards.hold(vm, 'checkout', 8010);
    await Future<void>.delayed(Duration.zero);
    forwards.dispose();
    raising.complete(_Forward(() => closed++));
    await held;

    expect(closed, 1);
  });

  // The harm: two raises for one port at once, the second failing on the port the first holds, and
  // its error said although the first forward is up.
  test('a homeserver asked for twice at once is raised once', () async {
    final settings = Settings(MemorySettingsStore());
    final raising = Completer<HeldForward>();
    var raised = 0;
    final forwards = HomeserverForwards(
      settings,
      raise: (machine, port) {
        raised++;
        return raising.future;
      },
      answers: (port) async => true,
    );
    addTearDown(forwards.dispose);

    final first = forwards.hold(vm, 'checkout', 8010);
    final second = forwards.retry(vm, 'checkout');
    await Future<void>.delayed(Duration.zero);
    raising.complete(_Forward(() {}));
    await Future.wait(<Future<void>>[first, second]);

    expect(raised, 1);
    expect(forwards.problemOf(vm, 'checkout'), isNull);
  });
}
