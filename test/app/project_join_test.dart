import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/signed_host.dart';

void main() {
  // Harm: the absent replacement contract must not trigger an old credential-based join.
  test('joining without the verified boundary leaves saved state and host processes alone', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final join = ProjectJoin(project: 'demo', machines: machines, settings: settings);
    addTearDown(join.dispose);
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, isNotNull);
    expect(settings.projectHost('demo'), isNull);
    expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
  });
}
