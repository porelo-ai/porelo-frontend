import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/host_admin.dart';
import '../support/host_process.dart';
import '../support/host_rental.dart';
import '../support/host_registry.dart';
import '../support/signed_host.dart';

void main() {
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() async {
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    runs = HostRuns(machines, hostAccess: access, environment: {'XDG_STATE_HOME': Directory.systemTemp.path});
  });
  tearDown(() {
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });

  // Harm: an unready rental is published, or a still-rented host loses its card.
  test('SSH host card is filed only after checked ready and deleted after confirmed give-back', () async {
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    final record = signedSetup;
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = owner.start(project: 'orchard', record: record, session: session, settings: settings);
    process.line(const Step('up', StepState.done, address: '203.0.113.7'));
    process.line(Step('host', StepState.host, host: PreparedHost.read(sshCompletion())));
    await Future<void>.delayed(Duration.zero);
    expect(fixture.changes, isEmpty, reason: 'a host line before process exit is not ready');
    process.end(0);
    await run.finished;
    expect(fixture.changes.map((change) => change.action), ['host-card']);
    expect(run.ready, isTrue);
    final downProcess = HostProcess();
    final down = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => downProcess);
    addTearDown(down.dispose);
    final future = down.down();
    downProcess.line(const Step('give-back', StepState.done, address: '203.0.113.7'));
    await Future<void>.delayed(Duration.zero);
    await owner.confirmDown('orchard', down);
    expect(fixture.changes, hasLength(1), reason: 'give-back still runs');
    downProcess.end(0);
    await future;
    await owner.confirmDown('orchard', down);
    expect(fixture.changes.map((change) => change.action), ['host-card', 'delete-card']);
  });

  // Harm: name reuse rents a server before pending registry deletion is resolved.
  test('reusing a returned host waits for deletion then starts a fresh lifecycle', () async {
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    final record = signedSetup;
    await settings.rememberHostUp('orchard', record);
    await settings.rememberHostReturned('orchard');
    var starts = 0;
    HostSession session() => HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        starts++;
        return HostProcess()
          ..line(const Step('up', StepState.done, address: '203.0.113.7'))
          ..line(Step('host', StepState.host, host: PreparedHost.read(sshCompletion())))
          ..end(0);
      },
    );
    final blockedSession = session();
    final blocked = owner.start(project: 'orchard', record: record, session: blockedSession, settings: settings);
    await blocked.finished;
    expect(starts, 0, reason: 'pending deletion must be resolved before renting');
    await owner.resume(blocked);
    expect(starts, 0, reason: 'resuming a refused setup must also wait for deletion');
    await access.bringToHost('orchard');
    final fresh = owner.start(project: 'orchard', record: record, session: session(), settings: settings);
    await fresh.finished;
    expect(starts, 1);
    expect(fresh.problem, isNull);
    expect(settings.hostReturned('orchard'), isFalse);
    expect(fixture.changes.map((change) => change.action), ['delete-card', 'host-card']);
  });

  // Harm: a retained replacement callback can change a rented server after admin access is revoked.
  test('legacy replacement refuses a revoked admin before its setup adapter', () async {
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    await settings.rememberHostUp(
      'orchard',
      HostUpRecord.fromStored({...legacyRental(), 'host': 'orchard', 'hostName': 'orchard'})!,
    );
    var replacements = 0;
    final owner = HostRuns(
      machines,
      hostAccess: access,
      environment: {'XDG_STATE_HOME': Directory.systemTemp.path},
      setupAgain: (_, record) async {
        replacements++;
        return record;
      },
    );
    addTearDown(owner.dispose);
    await owner.of('orchard')!.checked;
    fixture.actor = const HostAdminIdentity('bob', personFingerprint);
    await owner.again('orchard');
    expect(replacements, 0, reason: 'revocation must stop the adapter before it can change the server');
    expect(settings.hostUp('orchard')!.legacy, isTrue);
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
