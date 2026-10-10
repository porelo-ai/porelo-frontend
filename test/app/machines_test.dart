import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/app/machines.dart';
import 'package:sokar_frontend/client.dart';
import 'package:sokar_frontend/src/app/fleet_model.dart';
import 'package:sokar_frontend/src/app/settings.dart';

import '../features/support/world.dart';

/// Which socket the interface opens when nothing has been stored yet.
///
/// One line of code, and it was silently dropped by the rework that made several machines
/// possible: `SOKAR_SOCKET` stopped being read, so the window opened on the local runtime socket
/// and said it could not connect. Every test passed. This is the guard that was missing.
void main() {
  test('SOKAR_SOCKET names the machine to open', () {
    final machine = Machine.local(
      environment: const <String, String>{'SOKAR_SOCKET': '/tmp/sokar-mock.sock'},
    );

    expect(machine.socketPath, '/tmp/sokar-mock.sock');
    expect(machine.name, 'sokar-mock.sock');
  });

  // Linux only: there is no local daemon on Windows; Sokar runs in WSL there.
  test('without it, the local daemon', () {
    final machine = Machine.local(environment: const <String, String>{});

    expect(machine.name, 'this machine');
    expect(machine.socketPath, endsWith('/sokar/sokard.sock'));
  }, tags: 'linux');

  test('a machine exists before anything has been read back from disk', () {
    // The frame is drawn before load() can finish. A Machines with nothing in it yet crashed the
    // first frame, and the window that came up said it could not connect.
    final machines = Machines(Settings(MemorySettingsStore()));

    expect(machines.all, hasLength(1));
    expect(machines.of(machines.current), isNotNull);
    machines.dispose();
  });

  test('two machines that cannot say which node they are are not the same node', () async {
    // **Absence is not a value.** A daemon older than `Node()` answers nothing, and two machines
    // both saying nothing are not thereby one — which would be the very failure the method
    // exists to prevent, arriving from the other side.
    //
    // Held here rather than in a scenario because the state has to be exact: the local machine
    // records its id as the frame comes up, so a feature step can only ever clear one of the two.
    final machines = Machines(
      Settings(MemorySettingsStore()),
      // The features' own fake, so this is a backend that really answers rather than a stub
      // written to make one assertion pass.
      reach: (machine) => FakeBackend(const <Task>[])..nodeId = '',
      tunnels: FakeTunnels(),
    );
    await machines.add(const Machine(name: 'other', socketPath: '/tmp/other.sock'));
    // Both are connected and both answered nothing, which is the state that matters: one machine
    // could never be the same node as anything.
    await Future<void>.delayed(Duration.zero);

    expect(machines.all, hasLength(2));
    for (final machine in machines.all) {
      expect(machines.nodeOf(machine), isEmpty);
      expect(machines.sameNodeAs(machine), isEmpty);
    }
    machines.dispose();
  });

  test('a WSL distribution in the list is said to be unreachable here, and no socket is tried', () async {
    final machines = Machines(Settings(MemorySettingsStore(<String, Object?>{
      'machines': <Object?>[
        <String, Object?>{'name': 'Ubuntu on this PC', 'kind': 'wsl', 'distribution': 'Ubuntu'},
      ],
    })), tunnels: FakeTunnels());
    await machines.load();
    final machine = machines.all.single;
    final fleet = machines.of(machine);
    await fleet.connect();

    expect(machine.where, 'WSL: Ubuntu');
    expect(fleet.reachability, Reachability.unreachable);
    expect(fleet.status, contains('The WSL distribution Ubuntu is reached from Windows'));
    expect(fleet.status, isNot(contains('cannot reach')), reason: 'no socket path was tried');
    machines.dispose();
  });

  /// What a hand-edited or older settings file can contain.
  ///
  /// The load runs where nobody is waiting for it, so a throw in here does not surface as an
  /// error: the window simply opens with the machine list reduced to the local daemon, which
  /// looks exactly like having lost it.
  group('a stored machine that is not what it should be', () {
    test('a wrong type where a path belongs does not take the other machines with it', () async {
      final settings = Settings(MemorySettingsStore(<String, Object?>{
        'machines': <Object?>[
          <String, Object?>{'name': 'this machine', 'socket': '/run/user/1000/sokar/sokard.sock'},
          <String, Object?>{'name': 'broken', 'socket': 1000},
          <String, Object?>{'name': 'the build machine', 'socket': '/tmp/build.sock',
              'host': 'user@build', 'remoteSocket': '/run/user/1001/sokar/sokard.sock'},
        ],
      }));

      final machines = await settings.machines();

      expect(machines.map((each) => each.name), <String>['this machine', 'the build machine']);
    });

    test('an entry that is not an object at all is dropped', () async {
      final settings = Settings(MemorySettingsStore(<String, Object?>{
        'machines': <Object?>['just a string', <String, Object?>{'name': 'kept', 'socket': '/tmp/k.sock'}],
      }));

      expect((await settings.machines()).map((each) => each.name), <String>['kept']);
    });

    test('a nameless machine is dropped: nothing could tell it from another', () async {
      final settings = Settings(MemorySettingsStore(<String, Object?>{
        'machines': <Object?>[<String, Object?>{'socket': '/tmp/nameless.sock'}],
      }));

      expect(await settings.machines(), isEmpty);
    });
  });

  test('an empty value is not a socket path', () {
    final machine = Machine.local(environment: const <String, String>{'SOKAR_SOCKET': ''});

    expect(machine.name, 'this machine');
  });

  group('the mock, shown while it runs', () {
    const mock = Machine(name: 'mock', socketPath: '/tmp/sokar-mock.sock');
    final stored = <String, Object?>{
      'machines': <Object?>[
        <String, Object?>{'name': 'this machine', 'socket': '/run/user/1000/sokar/sokard.sock'},
      ],
    };

    Machines machinesWith(Settings settings, {required bool running}) => Machines(
          settings,
          reach: (machine) => FakeBackend(const <Task>[]),
          tunnels: FakeTunnels(),
          lookFor: mock,
          answers: (socket) async => running && socket == mock.socketPath,
        );

    test('a running mock is shown beside the stored machines, and never stored', () async {
      final store = MemorySettingsStore(stored);
      final machines = machinesWith(Settings(store), running: true);
      addTearDown(machines.dispose);

      await machines.load();
      expect(machines.all.map((each) => each.name), <String>['this machine', 'mock']);

      await machines.add(const Machine(name: 'other', socketPath: '/tmp/other.sock'));
      final kept = await Settings(store).machines();
      expect(kept.map((each) => each.name), <String>['this machine', 'other']);
    });

    test('a running mock is shown on a first run too, when nothing is stored yet', () async {
      final machines = machinesWith(Settings(MemorySettingsStore()), running: true);
      addTearDown(machines.dispose);

      await machines.load();

      // Once, whether or not SOKAR_SOCKET already opened it as the machine to start with.
      expect(machines.all.where((each) => each.socketPath == mock.socketPath), hasLength(1));
    });

    test('a mock that is not running is not shown', () async {
      final machines = machinesWith(Settings(MemorySettingsStore(stored)), running: false);
      addTearDown(machines.dispose);

      await machines.load();

      expect(machines.all.map((each) => each.name), <String>['this machine']);
    });

    test('SOKAR_SOCKET moves where the mock is looked for', () {
      expect(Machine.mock(environment: const <String, String>{}), mock);
      expect(
        Machine.mock(environment: const <String, String>{'SOKAR_SOCKET': '/tmp/other-mock.sock'}),
        const Machine(name: 'other-mock.sock', socketPath: '/tmp/other-mock.sock'),
      );
    });
  });
}
