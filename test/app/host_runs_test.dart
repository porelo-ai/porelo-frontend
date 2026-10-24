import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

const _record = HostUpRecord(
  scalewayProject: 'provider',
  account: 'porelo',
  tresor: 'drive',
  identity: '/keys/private',
  publicKey: '/keys/public',
  folder: null,
  repository: '',
  signingKey: '',
  collection: '',
  vpnPeerPublicKey: '',
  vpnPeerAddress: '',
);
const _done = Step(
  'up',
  StepState.done,
  address: '203.0.113.7',
  account: 'worker',
  socket: '/run/user/1007/porelo/porelod.sock',
);

void main() {
  late MemorySettingsStore store;
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() {
    store = MemorySettingsStore();
    settings = Settings(store);
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: _Tunnels());
    runs = HostRuns(machines, endpointFor: (name) => '/tmp/$name.sock');
  });
  tearDown(() {
    runs.dispose();
    machines.dispose();
    settings.dispose();
  });

  // Harm: work is sent to a host that does not exist when a progress line is mistaken for success.
  for (final code in [0, 65, 69, 75]) {
    test('only exit zero promotes the completed host after code $code', () async {
      final process = HostProcess();
      final session = HostSession(
        executable: 'fake',
        arguments: const ['--project', 'demo'],
        start: (_, _) async => process,
      );
      final run = runs.start(project: 'demo', session: session, record: _record);
      process.line(_done);
      process.words('Host protocol');
      await Future<void>.delayed(Duration.zero);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      expect(runs.preparing, [run]);
      process.end(code);
      await run.finished;
      expect(machines.all.where((machine) => machine.kind == 'host').length, code == 0 ? 1 : 0);
      expect(run.ready, code == 0);
      expect(runs.preparing, code == 0 ? isEmpty : [run]);
      expect(session.protocol.join('\n'), contains('Host protocol'));
      if (code == 0) {
        final machine = machines.all.singleWhere((machine) => machine.kind == 'host');
        expect(machine.host, 'worker@203.0.113.7');
        expect(machine.remoteSocket, '/run/user/1007/porelo/porelod.sock');
        expect(machine.identity, _record.identity);
      }
    });
  }

  for (final code in [0, 65, 69, 75]) {
    // Harm: losing confirmed tunnel settings prevents saving after restart; keeping an unready endpoint targets the wrong host.
    test('public tunnel settings are kept only after a ready host with exit $code', () async {
      final publicKey = base64Encode(List<int>.filled(32, 9));
      final peer = base64Encode(List<int>.filled(32, 7));
      final digest = List.filled(64, 'a').join();
      final record = HostUpRecord.fromStored({
        ..._record.stored,
        'vpnPeerPublicKey': peer,
        'vpnPeerAddress': '10.73.0.2/32',
        'collection': '/setup',
        'collectionSha256': digest,
      })!.withVpnFile('/previous.conf');
      await settings.rememberHostUp('demo', record);
      final process = HostProcess();
      final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
      final run = runs.start(
        project: 'demo',
        session: session,
        record: record,
        tunnel: HostTunnel(hostPublicKey: publicKey, peerPublicKey: peer),
        settings: settings,
      );
      process.line(_done);
      await Future<void>.delayed(Duration.zero);
      expect(settings.hostUp('demo')!.vpnHostPublicKey, isEmpty, reason: 'a progress line is not confirmation');
      process.end(code);
      await run.finished;
      final reopened = Settings(store);
      addTearDown(reopened.dispose);
      await reopened.load();
      final kept = reopened.hostUp('demo')!;
      expect(kept.vpnHostPublicKey, code == 0 ? publicKey : isEmpty);
      expect(kept.vpnEndpointAddress, code == 0 ? _done.address : isEmpty);
      expect(kept.vpnFile, '/previous.conf');
      expect(kept.collectionSha256, digest);
      expect(run.ready, code == 0);
    });
  }

  // Harm: work is sent to a host that does not exist when a later line takes its up back.
  test('exit zero after the up line was taken back adds no host', () async {
    final process = HostProcess();
    final session = HostSession(
      executable: 'fake',
      arguments: const ['--project', 'demo'],
      start: (_, _) async => process,
    );
    final run = runs.start(project: 'demo', session: session, record: _record);
    process.line(_done);
    process.line(const Step('up', StepState.started));
    await Future<void>.delayed(Duration.zero);
    process.end(0);
    await run.finished;
    expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
    expect(run.ready, isFalse);
    expect(runs.preparing, [run]);
  });

  // Harm: a stop waits unseen while the rented server keeps billing.
  test('a waiting host reaches Needs you and its resolution keeps the machine line', () async {
    final attention = Attention(machines)..hostRuns = runs;
    addTearDown(attention.dispose);
    final process = HostProcess();
    final next = HostProcess();
    var starts = 0;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async => starts++ == 0 ? process : next,
    );
    final run = runs.start(project: 'demo', session: session, record: _record);
    process.line(const Step('person', StepState.waiting, needs: ['drive'], text: 'Sign in to the drive'));
    process.end(75);
    await run.finished;
    expect(attention.openRows.single.kind, AttentionKind.host);
    expect(attention.openRows.single.machine, 'demo server');
    expect((attention.openRows.single.value as HostStop).text, 'Sign in to the drive');
    expect(attention.needingSomebody, 1);
    final resumed = runs.resume(run);
    next.line(_done);
    next.end(0);
    await resumed;
    expect(attention.openRows.where((row) => row.kind == AttentionKind.host), isEmpty);
    final resolved = attention.recentlyResolved.singleWhere((each) => each.row.kind == AttentionKind.host);
    expect(resolved.row.machine, 'demo server');
    expect((resolved.row.value as HostStop).text, 'Sign in to the drive');
  });

  // Harm: completion after restart erases the host's public VPN key and strands the ready host without VPN export.
  test('a stopped preparation keeps its public host key when restored and completed without a tunnel object', () async {
    final publicKey = base64Encode(List<int>.filled(32, 9));
    final record = _record.withTunnel(hostPublicKey: publicKey, address: '');
    final stopped = HostProcess();
    final run = runs.start(
      project: 'demo',
      record: record,
      settings: settings,
      session: HostSession(
        executable: 'fake',
        arguments: hostArguments(record, 'demo'),
        start: (_, _) async => stopped,
      ),
    );
    stopped.line(const Step('person', StepState.waiting, needs: ['drive']));
    stopped.end(75);
    await run.finished;
    final reopened = Settings(store);
    await reopened.load();
    final fleet = Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: _Tunnels());
    final process = HostProcess();
    final restored = _RestoredHostRuns(fleet, process);
    addTearDown(() {
      restored.dispose();
      fleet.dispose();
      reopened.dispose();
    });
    final resumed = restored.resume(restored.of('demo')!);
    process.line(_done);
    process.end(0);
    await resumed;
    final readBack = Settings(store);
    await readBack.load();
    expect(
      readBack.hostUp('demo')!.vpnHostPublicKey,
      publicKey,
      reason: 'restoring must not discard the public host key',
    );
    expect(restored.preparing, isEmpty);
    readBack.dispose();
  });

  // Harm: a refused setup cannot be corrected, or its replacement recovers another server after restart.
  test('a refused preparation can be replaced with corrected persisted arguments', () async {
    final refused = HostProcess();
    final first = runs.start(
      project: 'demo',
      record: _record,
      settings: settings,
      session: HostSession(
        executable: 'fake',
        arguments: hostArguments(_record, 'demo'),
        start: (_, _) async => refused,
      ),
    );
    refused.line(const Step('rent', StepState.refused));
    refused.end(65);
    await first.finished;
    final corrected = HostUpRecord.fromStored({
      ..._record.stored,
      'scalewayProject': 'corrected-provider',
      'account': 'corrected-account',
    })!;
    final process = HostProcess();
    final commands = <List<String>>[];
    final replacement = runs.start(
      project: 'demo',
      record: corrected,
      settings: settings,
      session: HostSession(
        executable: 'fake',
        arguments: hostArguments(corrected, 'demo'),
        start: (_, args) async {
          commands.add(List.of(args));
          return process;
        },
      ),
    );
    process.line(const Step('person', StepState.waiting, needs: ['drive']));
    process.end(75);
    await replacement.finished;
    expect(commands, [
      ['up', ...hostArguments(corrected, 'demo')],
    ]);
    final readBack = Settings(store);
    await readBack.load();
    expect(hostArguments(readBack.hostUp('demo')!, 'demo'), hostArguments(corrected, 'demo'));
    readBack.dispose();
  });

  for (final waiting in [false, true]) {
    // Harm: replacing active or stopped setup can rent twice or lose the server waiting for the person.
    test('start refuses replacing a ${waiting ? 'waiting' : 'running'} preparation', () async {
      final process = HostProcess();
      final first = runs.start(
        project: 'demo',
        record: _record,
        session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
      );
      final second = HostSession(executable: 'fake', arguments: const []);
      addTearDown(second.dispose);
      if (!waiting) {
        expect(
          () => runs.start(project: 'demo', session: second, record: _record),
          throwsStateError,
          reason: 'the attempt owns the project while its recovery record is being persisted',
        );
      }
      await Future<void>.delayed(Duration.zero);
      if (waiting) {
        process.line(const Step('person', StepState.waiting, needs: ['drive']));
        process.end(75);
        await first.finished;
      }
      expect(() => runs.start(project: 'demo', session: second, record: _record), throwsStateError);
      expect(runs.of('demo'), same(first));
      if (!waiting) {
        process.end(65);
        await first.finished;
      }
    });
  }

  // Harm: positional estimates hide remaining setup after conditional steps are skipped.
  test('remaining time matches task names and includes optional steps until passed', () async {
    var now = DateTime.utc(2000);
    final process = HostProcess();
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      now: () => now,
      start: (_, _) async => process,
    );
    addTearDown(session.dispose);
    final future = session.up();
    process.raw(
      '{"v":1,"state":"plan","steps":[{"task":"first","text":"First","seconds":20},{"task":"maybe","text":"Maybe","seconds":30,"when":true},{"task":"last","text":"Last","seconds":40}]}',
    );
    process.raw('{"step":"unplanned","state":"done"}');
    process.raw('{"step":"first","state":"started"}');
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 5));
    expect(session.stepSecondsLeft, 15);
    expect(session.secondsLeft, 85);
    process.raw('{"step":"last","state":"started","seconds":40}');
    await Future<void>.delayed(Duration.zero);
    expect(session.secondsLeft, 40);
    now = now.add(const Duration(seconds: 80));
    expect(session.secondsLeft, 0);
    process.end(65);
    await future;
  });
}

class _Tunnels extends Tunnels {
  @override
  Future<bool> raiseFor(Machine machine) async => true;
  @override
  Future<void> dropFor(Machine machine) async {}
}

class _RestoredHostRuns extends HostRuns {
  _RestoredHostRuns(super.machines, this.process) : super(endpointFor: (_) => '/restored.sock');
  final HostProcess process;
  @override
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: 'fake', arguments: hostArguments(record, project), start: (_, _) async => process);
}
