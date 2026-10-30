import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/host_admin.dart';
import '../support/host_process.dart';
import '../support/host_rental.dart';
import '../support/signed_host.dart';

void main() {
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() {
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    runs = HostRuns(machines, environment: {'XDG_STATE_HOME': Directory.systemTemp.path});
  });
  tearDown(() {
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });

  // Harm: incomplete or refused setup cannot become a usable server or lose recovery.
  for (final outcome in ['confirmed', 'missing card', 'refused', 'wrong host']) {
    test('$outcome setup retains recovery until SSH completion is confirmed', () async {
      final process = HostProcess();
      final run = runs.start(
        project: 'orchard',
        record: signedSetup,
        session: HostSession(
          executable: 'fake',
          arguments: const [],
          start: (_, _) async {
            expect(
              settings.hostUp('orchard')?.preparing,
              isTrue,
              reason: 'recovery must be durable before a command can rent',
            );
            return process;
          },
        ),
      );
      process.line(Step('up', outcome == 'refused' ? StepState.refused : StepState.done, address: '203.0.113.7'));
      if (outcome != 'missing card') {
        final values = hostValues();
        if (outcome == 'wrong host') values['name'] = 'elsewhere';
        process.line(Step('host', StepState.host, host: PreparedHost.read(values)));
      }
      process.end(0);
      await run.finished;
      final success = outcome == 'confirmed';
      expect(run.ready, success);
      expect(settings.hostUp('orchard')?.preparing, !success);
      expect(machines.all.where((m) => m.hostProject == 'orchard').length, success ? 1 : 0);
    });
  }

  // Harm: a legacy saved command must never be started even through a direct action call.
  test('legacy setup cannot start through HostRuns', () {
    final record = HostUpRecord.fromStored(legacyRental())!;
    final session = HostSession(executable: 'fake', arguments: const []);
    addTearDown(session.dispose);
    expect(() => runs.start(project: 'demo', record: record, session: session), throwsStateError);
  });
}
