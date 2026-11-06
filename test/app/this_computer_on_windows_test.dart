import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

// Guards a window on Windows that opens to a socket refusal it cannot fix, and a daemon listed twice.
void main() {
  late Desk previous;
  setUp(() {
    previous = desk;
    desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
  });
  tearDown(() {
    desk = previous;
    Machine.thisComputersDistribution = null;
  });

  final opened = <String>[];
  setUp(opened.clear);

  Machines machinesWith(Map<String, Object?> stored, {String? found = 'Ubuntu'}) => Machines(
    Settings(MemorySettingsStore(stored)),
    reach: (machine) {
      opened.add(machine.distribution);
      return FakeBackend(const <Task>[]);
    },
    tunnels: FakeTunnels(),
    thisComputersDistribution: () async => found,
  );

  const handAdded = <String, Object?>{
    'form': settingsForm,
    'machines': <Object?>[
      <String, Object?>{'name': 'WSL', 'kind': 'wsl', 'distribution': 'Ubuntu'},
    ],
  };

  test('a first start on Windows lists the WSL distribution as this computer, and no socket', () async {
    final machines = machinesWith(const <String, Object?>{});
    await machines.load();

    final listed = listedMachines(machines);
    expect(listed, hasLength(1));
    final only = listed.single;
    expect(only.kind, 'wsl');
    expect(only.distribution, 'Ubuntu');
    expect(only.isAlwaysListed, isTrue);
    expect(only.whyNotReachableOn(windows: true), isNull);
    expect(only.relayOn(windows: true, environment: const <String, String>{})?.kind, 'wsl');
    machines.dispose();
  });

  test('a distribution added by hand before is this computer once', () async {
    for (final found in <String?>['Ubuntu', null]) {
      final machines = machinesWith(handAdded, found: found);
      await machines.load();

      final listed = listedMachines(machines);
      expect(listed.map((each) => each.name), <String>['WSL'], reason: 'found $found');
      expect(listed.single.isAlwaysListed, isTrue);
      expect(opened.where((each) => each == 'Ubuntu'), hasLength(1), reason: 'opened once, found $found');
      machines.dispose();
      opened.clear();
    }
  });

  test('a distribution added under another name is not a second machine', () async {
    for (final found in <String?>['Ubuntu', null]) {
      final machines = machinesWith(const <String, Object?>{}, found: found);
      await machines.load();
      await machines.add(const Machine(name: 'WSL', socketPath: '', kind: 'wsl', distribution: 'Ubuntu'));

      expect(machines.all.where((each) => each.distribution == 'Ubuntu'), hasLength(1), reason: 'found $found');
      expect(machines.all.where((each) => each.distribution.isEmpty), isEmpty, reason: 'found $found');
      expect(machines.current.distribution, 'Ubuntu');
      expect(opened.where((each) => each == 'Ubuntu'), hasLength(1), reason: 'opened once, found $found');
      machines.dispose();
      opened.clear();
    }
  });
}
