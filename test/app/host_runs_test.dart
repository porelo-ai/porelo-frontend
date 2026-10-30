import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/homeserver_publishing.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_registry.dart';

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
// A host key, so completion waits for the VPN; without one the host files were supplied by hand.
const _vpnRecord = HostUpRecord(
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
  // 32 bytes in base64, as a WireGuard public key is.
  vpnHostPublicKey: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=',
  vpnEndpointAddress: '203.0.113.7',
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

  // Harm: a server rented but not yet reachable through the VPN drops out of recovery and is forgotten
  // on a restart while it is still billed.
  test('recovery is kept until the VPN check and cleared after it', () async {
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(project: 'demo', session: session, record: _vpnRecord, settings: settings);
    process.line(_done);
    process.end(0);
    await run.finished;
    expect(run.awaitingVpn, isTrue);
    expect(settings.hostUp('demo')!.preparing, isTrue, reason: 'up alone does not make the server reachable');
    await runs.vpnChecked(run, verified: true);
    expect(run.ready, isTrue);
    expect(settings.hostUp('demo')!.preparing, isFalse, reason: 'a reachable machine needs no recovery');
  });

  // Harm: the laptop's homeserver left published on the VPN for a host that is gone, or one closing refused unseen.
  test('the give-back closes the homeserver published for that host, and says where it could not', () async {
    final scratch = Directory.systemTemp.createTempSync('host-runs-homeserver-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    File('${scratch.path}/porelo/matrix/homeserver.conf')
      ..createSync(recursive: true)
      ..writeAsStringSync('PORELO_MATRIX_PORT=8008\nPORELO_MATRIX_PUBLISH=10.73.0.2:8008\n');
    final ran = <List<String>>[];
    var exitCode = 0;
    final published = HostRuns(
      machines,
      endpointFor: (name) => '/tmp/$name.sock',
      homeserver: HomeserverPublishing(
        configuration: '${scratch.path}/porelo',
        run: (_, arguments) async {
          ran.add(arguments);
          return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : 'publish: the socket could not be stopped\n');
        },
      ),
    );
    addTearDown(published.dispose);
    const record = HostUpRecord(
      scalewayProject: 'provider',
      account: 'porelo',
      tresor: 'drive',
      identity: '/keys/private',
      publicKey: '/keys/public',
      folder: null,
      repository: '',
      signingKey: '',
      collection: '',
      // The peer's key and address go together, as a tunnel's public settings are kept.
      vpnPeerPublicKey: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=',
      vpnPeerAddress: '10.73.0.2/32',
    );
    await settings.rememberHostUp('demo', record);
    String? said;
    Future<HostPreparation> givenBack() async {
      final process = HostProcess();
      final run = published.start(
        project: 'demo',
        session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
        record: record,
        settings: settings,
      );
      process
        ..line(const Step('give-back', StepState.done))
        ..end(0);
      await run.finished;
      final down = HostProcess()
        ..line(const Step('give-back', StepState.done))
        ..end(0);
      final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => down);
      addTearDown(session.dispose);
      await session.down();
      await published.confirmDown('demo', session);
      expect(ran, isEmpty, reason: 'the give-back itself waits on nothing of the transport');
      said = await published.closeHomeserver('demo');
      return run;
    }

    final closed = await givenBack();
    expect(ran.single, ['publish', '--off']);
    expect(closed.problem ?? '', isNot(contains('homeserver')), reason: 'closed: nothing to say about it');

    ran.clear();
    exitCode = 1;
    final refused = await givenBack();
    expect(ran.single, ['publish', '--off']);
    expect(refused.problem, contains('the socket could not be stopped'), reason: 'said where the run is shown');
    expect(said, contains('the socket could not be stopped'), reason: 'and to the dialog that gave it back');
  });

  // Harm: an unready rental is published, or a still-rented host loses its card.
  test('SSH host card is filed only after checked ready and deleted after confirmed give-back', () async {
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    final owner = HostRuns(machines, hostAccess: access);
    addTearDown(owner.dispose);
    final record = HostUpRecord.fromStored({..._record.stored, 'host': 'orchard', 'hostName': 'orchard'})!;
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = owner.start(project: 'orchard', record: record, session: session, settings: settings);
    process.line(_done);
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
    final record = HostUpRecord.fromStored({..._record.stored, 'host': 'orchard', 'hostName': 'orchard'})!;
    await settings.rememberHostUp('orchard', record);
    await settings.rememberHostReturned('orchard');
    var starts = 0;
    HostSession session() => HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        starts++;
        return HostProcess()
          ..line(_done)
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

  // Harm: an unchecked terminal exit zero must not make a host available for work.
  test('host completion without a verified VPN leaves the machine in preparation', () async {
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(project: 'demo', session: session, record: _vpnRecord);
    process.line(_done);
    process.end(0);
    await run.finished;
    expect(run.ready, isFalse, reason: 'no handshake for the expected public key has been checked');
    await runs.vpnChecked(run, verified: false);
    expect(run.ready, isFalse, reason: 'a VPN terminal that did not confirm the handshake');
    expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
  });

  // Harm: setup with manually supplied host files waits forever for a VPN step that refuses it, so the rented server is never usable.
  test('a completed host without a host public key is ready and in Machines', () async {
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(
      project: 'demo',
      session: session,
      record: _record,
      tunnel: HostTunnel(hostPublicKey: '', peerPublicKey: base64Encode(List<int>.filled(32, 7))),
      settings: settings,
    );
    process.line(_done);
    process.end(0);
    await run.finished;
    expect(run.ready, isTrue, reason: 'the VPN step refuses an empty host key, so waiting for it never ends');
    expect(runs.preparing, isEmpty, reason: 'a run left in preparation is stuck');
    expect(machines.all.where((machine) => machine.kind == 'host').single.host, 'worker@203.0.113.7');
  });

  // Harm: one host's working VPN must not enable another host's down action or clear its cleanup.
  test('VPN refresh tracks links reachability and cleanup separately for each host', () async {
    final links = <String, bool>{'first': true, 'second': false};
    final probed = <String>[];
    final probing = HostRuns(
      machines,
      probeHostLink: (host) async {
        probed.add(host);
        return links[host]!;
      },
      pingHost: (host) async => links[host]!,
    );
    addTearDown(probing.dispose);
    for (final host in links.keys) {
      await machines.add(Machine(name: host, kind: 'host', hostProject: host, socketPath: '/unused/$host'));
    }
    await probing.refreshVpns();
    expect(probed, containsAll(links.keys));
    expect(probing.vpnLinkFor('first'), isTrue);
    expect(probing.vpnLinkFor('second'), isFalse);
    expect(probing.vpnDown, {'second'});
    for (final machine in machines.all.where((machine) => machine.kind == 'host')) {
      probing.rememberVpnToTakeDown(machine);
    }
    await probing.refreshVpns();
    expect(probing.vpnsToTakeDown.map((machine) => machine.hostProject), [
      'first',
      'second',
    ], reason: 'an absent link alone cannot confirm persistent names and trust were removed');
    probing.vpnCleanupFinished('second', completed: true);
    await probing.refreshVpns();
    expect(probing.vpnsToTakeDown.map((machine) => machine.hostProject), ['first']);
    links['first'] = false;
    links['second'] = true;
    probing.vpnCleanupFinished('first', completed: true);
    await probing.refreshVpns();
    expect(probing.vpnLinkFor('first'), isFalse);
    expect(probing.vpnLinkFor('second'), isTrue);
    expect(probing.vpnDown, {'first'});
    expect(probing.vpnsToTakeDown, isEmpty);
  }, testOn: 'linux');

  // Harm: a stale VPN probe marks a working host's VPN as down, or puts a removed host back into the warning.
  test('only the latest VPN probe writes, and only for hosts still present', () async {
    final pings = <Completer<bool>>[];
    final links = <Completer<bool>>[];
    final probing = HostRuns(
      machines,
      endpointFor: (name) => '/tmp/$name.sock',
      ping: () {
        final answer = Completer<bool>();
        pings.add(answer);
        return answer.future;
      },
      probeLink: () {
        final answer = Completer<bool>();
        links.add(answer);
        return answer.future;
      },
    );
    addTearDown(probing.dispose);
    const server = Machine(
      name: 'demo server',
      kind: 'host',
      socketPath: '/tmp/demo server.sock',
      host: 'worker@203.0.113.7',
      remoteSocket: '/run/user/1007/porelo/porelod.sock',
      identity: '/keys/private',
      hostProject: 'demo',
    );
    await machines.add(server);
    final older = probing.refreshVpns();
    final newer = probing.refreshVpns();
    expect(pings, hasLength(2), reason: 'each refresh probes once');
    pings[1].complete(true);
    links[1].complete(true);
    await newer;
    pings[0].complete(false);
    links[0].complete(false);
    await older;
    expect(probing.vpnDown, isEmpty, reason: 'the newer probe answered; the older one is stale');
    expect(probing.vpnLinkUp, isTrue, reason: 'a stale absent link must not route a new VPN up command');
    expect(probing.vpnUp, isTrue, reason: 'the newer link and ping both succeeded');
    final removedMeanwhile = probing.refreshVpns();
    await machines.forget(machines.all.singleWhere((machine) => machine.kind == 'host'));
    pings[2].complete(false);
    links[2].complete(true);
    await removedMeanwhile;
    expect(probing.vpnDown, isEmpty, reason: 'a host removed while the probe ran is not put back');
  }, testOn: 'linux');

  for (final link in <bool?>[false, true, null]) {
    for (final answers in [false, true]) {
      // Harm: confusing reachability with link presence routes the wrong root action or hides lost connectivity.
      test('VPN refresh keeps link $link separate from ping $answers', () async {
        await machines.add(
          const Machine(name: 'demo server', kind: 'host', hostProject: 'demo', socketPath: '/unused'),
        );
        final probing = HostRuns(
          machines,
          ping: () async => answers,
          probeLink: () async {
            if (link == null) throw const HostFilesRefused('The local VPN interface could not be checked.');
            return link;
          },
        );
        addTearDown(probing.dispose);
        await probing.refreshVpns();
        expect(
          probing.vpnLinkUp,
          link,
          reason: 'root actions follow link presence even when the server does not answer',
        );
        expect(probing.vpnUp, link == true && answers, reason: 'reachability requires both a link and an answer');
        expect(
          probing.vpnDown,
          link == true && answers ? isEmpty : {'demo server'},
          reason: 'a failed or unknown check must keep the host in the lost connectivity warning',
        );
      }, testOn: 'linux');
    }
  }

  // Harm: work is sent to a host that does not exist when a progress line is mistaken for success.
  for (final code in [0, 65, 69, 75]) {
    test('only exit zero promotes the completed host after code $code', () async {
      final process = HostProcess();
      final session = HostSession(
        executable: 'fake',
        arguments: const ['--project', 'demo'],
        start: (_, _) async => process,
      );
      final run = runs.start(project: 'demo', session: session, record: _vpnRecord);
      process.line(_done);
      process.words('Host protocol');
      await Future<void>.delayed(Duration.zero);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      expect(runs.preparing, [run]);
      process.end(code);
      await run.finished;
      expect(run.ready, isFalse, reason: 'host completion still needs the local VPN');
      if (code == 0) await runs.vpnChecked(run, verified: true);
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
      expect(run.ready, isFalse);
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
    await runs.vpnChecked(run, verified: true);
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
    final state = await Directory.systemTemp.createTemp('restored-host-');
    final restored = _RestoredHostRuns(
      fleet,
      process,
      environment: {'XDG_STATE_HOME': state.path, 'LOCALAPPDATA': state.path},
    );
    addTearDown(() async {
      restored.dispose();
      fleet.dispose();
      reopened.dispose();
      await state.delete(recursive: true);
    });
    final resumed = restored.resume(restored.of('demo')!);
    process.line(_done);
    process.end(0);
    await resumed;
    await restored.vpnChecked(restored.of('demo')!, verified: true);
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
  _RestoredHostRuns(super.machines, this.process, {super.environment}) : super(endpointFor: (_) => '/restored.sock');
  final HostProcess process;
  @override
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: 'fake', arguments: hostArguments(record, project), start: (_, _) async => process);
}
