import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/app/machines.dart';
import 'package:sokar_frontend/src/app/settings.dart';

/// The machine list in `frontend.json` is read by another repository: `sokar-intellij`'s plugin takes
/// `machines[]` with `name`, `socket`, `host` and `remoteSocket`. A rename here
/// is a break there, so it is said in the channel first, and this test is what makes it deliberate.
void main() {
  test('a machine reached through a tunnel is stored with the four fields the plugin reads', () {
    const machine = Machine(
        name: 'vm',
        socketPath: '/run/user/1000/sokar-tunnel-vm.sock',
        host: 'somebody@192.0.2.10',
        remoteSocket: '/run/user/1012/sokar/sokard.sock');

    expect(machine.stored, <String, Object?>{
      'name': 'vm',
      'socket': '/run/user/1000/sokar-tunnel-vm.sock',
      'host': 'somebody@192.0.2.10',
      'remoteSocket': '/run/user/1012/sokar/sokard.sock',
    });
  });

  test('a machine somebody else forwards, or this computer, is stored without host and remote socket', () {
    const machine = Machine(name: 'here', socketPath: '/run/user/1000/sokar/sokard.sock');

    expect(machine.stored, <String, Object?>{'name': 'here', 'socket': '/run/user/1000/sokar/sokard.sock'});
    expect(Machine.fromStored(machine.stored).needsATunnel, isFalse);
  });

  test('a WSL distribution is stored as the plugin is told to expect it, with no socket', () {
    const stored = <String, Object?>{'name': 'Ubuntu on this PC', 'kind': 'wsl', 'distribution': 'Ubuntu'};

    final machine = Machine.fromStored(stored);

    expect(machine.kind, 'wsl');
    expect(machine.distribution, 'Ubuntu');
    expect(machine.stored, stored);
  });

  test('an entry of a kind this version does not know is kept as it was, every field', () {
    const stored = <String, Object?>{'name': 'later', 'kind': 'teleport', 'cluster': 'x', 'port': 7};

    expect(Machine.fromStored(stored).stored, stored);
  });

  test('neither a WSL entry nor an unknown kind is reached here; a plain socket is', () {
    expect(Machine.fromStored(const <String, Object?>{'name': 'w', 'kind': 'wsl', 'distribution': 'Ubuntu'}).whyNotReachableHere,
        contains('WSL distribution Ubuntu is reached from Windows'));
    expect(Machine.fromStored(const <String, Object?>{'name': 'l', 'kind': 'teleport'}).whyNotReachableHere,
        contains('"teleport"'));
    expect(const Machine(name: 'here', socketPath: '/run/user/1000/sokar/sokard.sock').whyNotReachableHere, isNull);
  });

  test('loading and saving the list keeps a WSL entry and an unknown kind beside the others', () async {
    final entries = <Map<String, Object?>>[
      <String, Object?>{'name': 'here', 'socket': '/run/user/1000/sokar/sokard.sock'},
      <String, Object?>{'name': 'Ubuntu on this PC', 'kind': 'wsl', 'distribution': 'Ubuntu'},
      <String, Object?>{'name': 'later', 'kind': 'teleport', 'cluster': 'x'},
    ];
    final store = MemorySettingsStore(<String, Object?>{'machines': entries});
    final settings = Settings(store);
    await settings.load();

    final loaded = await settings.machines();
    await settings.rememberMachines(loaded);

    expect(<Map<String, Object?>>[for (final each in await settings.machines()) each.stored], entries);
  });
}
