import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

const _record = HostUpRecord(
  scalewayProject: 'provider',
  account: 'worker',
  tresor: 'drive',
  folder: null,
  signingKey: '',
  identity: '/keys/private',
  publicKey: '/keys/public',
  collection: '',
  vpnPeerPublicKey: '',
  vpnPeerAddress: '',
);

void main() {
  // Harm: dropping preparation during another settings write hides a billing server after restart.
  test('preparation and its UTC start survive storage and public settings copies', () async {
    final instant = DateTime.utc(2000).toIso8601String();
    final stored = {..._record.stored, 'preparing': true, 'startedAt': instant};
    final record = HostUpRecord.fromStored(stored)!;
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    for (final copy in [record, record.withVpnFile('/vpn.conf'), record.withTunnel(hostPublicKey: '', address: '')]) {
      await settings.rememberHostUp('demo', copy);
      final reopened = Settings(store);
      await reopened.load();
      expect(reopened.hostUp('demo')!.stored['preparing'], true);
      expect(reopened.hostUp('demo')!.stored['startedAt'], instant);
      expect(reopened.hostUp('demo')!.arguments('demo'), _record.arguments('demo'));
      reopened.dispose();
    }
    expect(HostUpRecord.fromStored(_record.stored), isNotNull, reason: 'older records remain usable');
  });

  // Harm: malformed preparation fields can crash startup or silently turn recovery into a ready server.
  test('malformed preparation fields are refused field by field', () {
    final instant = DateTime.utc(2000).toIso8601String();
    for (final invalid in <Map<String, Object?>>[
      {'preparing': 'true', 'startedAt': instant},
      {'preparing': 1, 'startedAt': instant},
      {'preparing': null, 'startedAt': instant},
      {'preparing': true},
      {'preparing': true, 'startedAt': null},
      {'preparing': true, 'startedAt': 7},
      {'preparing': true, 'startedAt': 'not-an-instant'},
      {'preparing': true, 'startedAt': '2000-01-01T00:00:00.000'},
    ]) {
      expect(HostUpRecord.fromStored({..._record.stored, ...invalid}), isNull, reason: '$invalid must not load');
    }
  });

  for (final code in [0, 65, 69, 75]) {
    // Harm: a host can be rented before recovery is durable, or disappear after an unconfirmed completion.
    test('recovery is durable before up and cleared only on ready completion with exit $code', () async {
      final store = MemorySettingsStore();
      final settings = Settings(store);
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final runs = HostRuns(machines, endpointFor: (_) => '/prepared.sock');
      addTearDown(() {
        runs.dispose();
        machines.dispose();
        settings.dispose();
      });
      final process = HostProcess();
      Map<String, Object?>? beforeStart;
      final session = HostSession(
        executable: 'fake',
        arguments: hostArguments(_record, 'demo'),
        start: (_, _) async {
          final read = Settings(store);
          await read.load();
          beforeStart = read.hostUp('demo')?.stored;
          read.dispose();
          return process;
        },
      );
      final run = runs.start(project: 'demo', session: session, record: _record, settings: settings);
      process.line(
        const Step(
          'up',
          StepState.done,
          address: '203.0.113.7',
          account: 'worker',
          socket: '/run/user/1007/porelo/porelod.sock',
        ),
      );
      process.end(code);
      await run.finished;
      expect(beforeStart?['preparing'], isTrue, reason: 'recovery must be stored before a process can rent');
      final startedAt = DateTime.tryParse(beforeStart?['startedAt'] as String? ?? '');
      expect(startedAt?.isUtc, isTrue);
      final reopened = Settings(store);
      await reopened.load();
      final restoredMachines = Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final restored = HostRuns(restoredMachines);
      expect(restored.preparing.map((run) => run.project), code == 0 ? isEmpty : ['demo']);
      expect(machines.all.where((machine) => machine.kind == 'host'), code == 0 ? hasLength(1) : isEmpty);
      restored.dispose();
      restoredMachines.dispose();
      reopened.dispose();
    });
  }
}
