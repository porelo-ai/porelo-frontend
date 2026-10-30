// Linux only: private config publication uses chmod and Unix control sockets.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/homeserver_forwards.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeTerminal;

const publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  late Directory folder;
  late Machine host;
  late _Unlock unlock;
  late List<List<String>> launches;
  late List<List<String>> runs;
  late List<_Process> processes;
  late Tunnels tunnels;
  late _Process Function() nextProcess;
  Future<ProcessResult> Function()? checkControl;
  late int keyChecks;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('h-');
    final card = HostCardSsh(
      name: 'alpha',
      address: 'alpha.example.org',
      sshPort: 2222,
      hostKey: publicKey,
      login: 'alice',
      publicKey: publicKey,
      uid: 1001,
      returnSocket: '/run/porelo-host/people/alice/messenger.sock',
      webPort: 18080,
      gitPort: 18081,
      matrixPort: 18082,
    );
    host = Machine.fromHostCard(
      card,
      socketPath: '${folder.path}/d',
      sshConfig: '${folder.path}/porelo/ssh/alpha.conf',
    );
    unlock = _Unlock();
    launches = [];
    runs = [];
    processes = [];
    nextProcess = _Process.new;
    checkControl = null;
    keyChecks = 0;
    tunnels = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      start: (command) async {
        launches.add(command);
        final process = nextProcess();
        processes.add(process);
        return process;
      },
      run: (command) async {
        runs.add(command);
        if (checkControl != null) return checkControl!();
        return ProcessResult(0, 0, '', '');
      },
      keyAvailable: (_) async {
        keyChecks++;
        return true;
      },
      portsAvailable: (_) async {},
      unlocker: unlock,
      messengerSocket: '${folder.path}/m',
    );
    addTearDown(() async {
      await tunnels.dropEverything();
      tunnels.dispose();
      folder.deleteSync(recursive: true);
    });
  });

  // Prevents SSH from using personal trust, another identity or externally bound services.
  test('a card never reuses or drops a same-name non-card tunnel', () async {
    final other = Machine(name: host.name, socketPath: '${folder.path}/other', host: 'alice@other', remoteSocket: '/d');
    final server = await ServerSocket.bind(InternetAddress(other.socketPath, type: InternetAddressType.unix), 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());
    // A serving legacy endpoint is refused; its managed entry still must not satisfy a card raise.
    await tunnels.raiseFor(other);
    expect(await tunnels.raiseFor(host), isTrue);
    expect(launches, hasLength(1));
    expect(launches.single, contains(host.sshConfig));
    await tunnels.dropFor(other);
    expect(processes.single.killed, isFalse);
  });

  // Prevents reporting a second daemon endpoint as up on a master that never forwarded it.
  test('a second endpoint for one card is refused without dropping the first master', () async {
    await tunnels.raiseFor(host);
    final other = host.withSocketPath('${folder.path}/second');
    expect(await tunnels.raiseFor(other), isFalse);
    await tunnels.dropFor(other);
    expect(processes.single.killed, isFalse);
    expect(await tunnels.raiseFor(host), isTrue);
    expect(launches, hasLength(1));
  });

  // Prevents path validation from escaping as an unhandled future and leaving the host raising.
  test('an invalid local endpoint returns a refusal and never launches', () async {
    final bad = host.withSocketPath('relative');
    expect(await tunnels.raiseFor(bad), isFalse);
    expect(tunnels.of(bad)!.state, TunnelState.down);
    expect(tunnels.of(bad)!.problem, isNotEmpty);
    expect(launches, isEmpty);
  });

  // Prevents conflicting imported ports from throwing through connection callers.
  test('a conflicting card returns a refusal naming both hosts before publication', () async {
    tunnels.registerCards([host]);
    final other = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
      sshConfig: '${folder.path}/beta.conf',
    );
    expect(await tunnels.raiseFor(other), isFalse);
    expect(tunnels.of(other)!.problem, allOf(contains('alpha'), contains('beta'), contains('18080')));
    expect(File(other.sshConfig).existsSync(), isFalse);
    expect(launches, isEmpty);
  });

  // Prevents unwatched card probes from leaving processes and fixed port reservations alive.
  for (final keyslots in [false, true]) {
    test('an unwatched card ${keyslots ? 'keyslot count' : 'trial'} releases its tunnel', () async {
      if (keyslots) {
        expect(await countKeyslots(host, reach: (_) => _StoppedBackend(), tunnels: tunnels), isNull);
      } else {
        await tryAMachine(host, reach: (_) => _StoppedBackend(), tunnels: tunnels);
      }
      expect(processes.single.killed, isTrue);
      expect(tunnels.manages(host), isFalse);
      tunnels.registerCards([
        Machine.fromHostCard(
          HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
          socketPath: '${folder.path}/b',
        ),
      ]);
    });
  }

  // Prevents replacing a watched host from retaining its old process or rejecting its own reserved ports.
  test('overlapping candidate probes retain their shared master until both finish', () async {
    final first = _PausedBackend();
    final second = _PausedBackend();
    final trial = tryAMachine(host, reach: (_) => first, tunnels: tunnels);
    await first.entered.future;
    final count = countKeyslots(host, reach: (_) => second, tunnels: tunnels);
    await second.entered.future;
    first.finish.complete();
    await trial;
    expect(processes.single.killed, isFalse);
    second.finish.complete();
    await count;
    expect(processes.single.killed, isTrue);
    expect(tunnels.manages(host), isFalse);
  });

  // Prevents a candidate probe from closing a master promoted to a watched connection.
  test('releasing a pending trial preserves a concurrent watched connection', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final trial = tunnels.holdForTrial(host);
    await entered.future;
    final releasing = trial.release();
    final watching = tunnels.raiseFor(host);
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await watching, isTrue);
    await releasing;
    expect(processes.single.killed, isFalse, reason: 'the new watcher still needs the shared master');
    expect(tunnels.manages(host), isTrue);
  });

  // Prevents an unsaved probe from losing its control socket and fixed ports to another endpoint.
  test('replacing the watched cards preserves an unsaved trial owner', () async {
    final trial = tunnels.holdForTrial(host);
    expect(await trial.ready, isTrue);
    await Future<void>.sync(() => tunnels.replaceCards([]));
    final other = host.withSocketPath('${folder.path}/second');
    expect(await tunnels.raiseFor(other), isFalse, reason: 'the unsaved trial still owns this card');
    expect(launches, hasLength(1));
    expect(processes.single.killed, isFalse);
    await tunnels.dropFor(other);
    await trial.release();
    expect(processes.single.killed, isTrue);
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(() => tunnels.registerCards([beta]), returnsNormally);
  });

  // Prevents a canceled queued probe from starting SSH, unlock, or socket publication.
  test('releasing a trial queued behind a drop skips its raise', () async {
    final old = _SlowProcess();
    nextProcess = () => processes.isEmpty ? old : _Process();
    await tunnels.raiseFor(host);
    final dropping = tunnels.dropFor(host);
    addTearDown(() async {
      old.end('');
      await dropping;
    });
    await old.stopping.future;
    final trial = tunnels.holdForTrial(host);
    final releasing = trial.release();
    old.end('');
    await dropping;
    await releasing;
    expect(await trial.ready, isFalse, reason: 'a released queued probe no longer needs a connection');
    expect(launches, hasLength(1));
    expect(unlock.calls, hasLength(1));
    expect(tunnels.manages(host), isFalse);
  });

  // Prevents cleanup from rethrowing a consumed connection failure or dropping another consumer.
  test('releasing a failed trial does not repeat its ready error', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      if (!entered.isCompleted) entered.complete();
      return checked.future;
    };
    final first = tunnels.holdForTrial(host);
    final firstFailed = expectLater(first.ready, throwsStateError);
    await entered.future;
    final second = tunnels.holdForTrial(host);
    final secondFailed = expectLater(second.ready, throwsStateError);
    checked.completeError(StateError('control check failed'));
    await firstFailed;
    await secondFailed;
    checkControl = null;
    expect(await tunnels.raiseFor(host), isTrue);
    await expectLater(first.release(), completes);
    await expectLater(second.release(), completes);
    expect(processes.last.killed, isFalse, reason: 'the watcher still retains the recovered master');
    expect(tunnels.of(host)!.state, TunnelState.up);
  });

  // Prevents a failed prior start from poisoning a later connect after cleanup.
  test('a queued watcher raises after the preceding raise and drop fail', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final raising = tunnels.raiseFor(host);
    final failed = expectLater(raising, throwsStateError);
    await entered.future;
    final dropping = tunnels.dropFor(host);
    // A serial drop has no reason to repeat its predecessor's error.
    final dropped = dropping.then<Object?>((_) => null, onError: (Object error) => error);
    final reconnecting = tunnels.raiseFor(host);
    final reconnected = expectLater(reconnecting, completion(isTrue));
    checkControl = null;
    checked.completeError(StateError('old control check failed'));
    await failed;
    await dropped;
    await reconnected;
    expect(launches, hasLength(2));
    expect(processes.first.killed, isTrue);
    expect(processes.last.killed, isFalse);
  });

  // Prevents a teardown error from being delivered to a fresh connection request.
  for (final probe in [false, true]) {
    test('a queued ${probe ? 'trial' : 'watcher'} raises after the preceding drop fails', () async {
      final old = _FailingStopProcess();
      nextProcess = () => processes.isEmpty ? old : _Process();
      await tunnels.raiseFor(host);
      final dropped = expectLater(tunnels.dropFor(host), throwsStateError);
      final trial = probe ? tunnels.holdForTrial(host) : null;
      final connected = expectLater(trial?.ready ?? tunnels.raiseFor(host), completion(isTrue));
      await dropped;
      await connected;
      expect(launches, hasLength(2));
      expect(old.killed, isTrue);
      expect(processes.last.killed, isFalse);
      await trial?.release();
    });
  }

  // Prevents a finishing drop from erasing a reservation submitted while it was stopping.
  for (final replace in [false, true]) {
    test('${replace ? 'replacing' : 'registering'} a card during drop preserves its reservation', () async {
      final old = _SlowProcess();
      nextProcess = () => processes.isEmpty ? old : _Process();
      await tunnels.raiseFor(host);
      final dropping = tunnels.dropFor(host);
      addTearDown(() async {
        old.end('');
        await dropping;
      });
      await old.stopping.future;
      final reserving = Future<void>.sync(() => replace ? tunnels.replaceCards([host]) : tunnels.registerCards([host]));
      old.end('');
      await dropping;
      await reserving;
      final beta = Machine.fromHostCard(
        HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
        socketPath: '${folder.path}/b',
      );
      expect(
        () => tunnels.registerCards([beta]),
        throwsA(isA<HostFilesRefused>()),
        reason: 'the later registration must reserve the fixed ports after cleanup',
      );
      expect(launches, hasLength(1));
    });
  }

  // Prevents a queued list replacement from freeing a newly registered host's fixed ports.
  test('a queued replacement preserves later registration on a new host queue', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    addTearDown(() {
      if (!checked.isCompleted) checked.complete(ProcessResult(0, 0, '', ''));
    });
    final raising = tunnels.raiseFor(host);
    await entered.future;
    final replacing = Future<void>.sync(() => tunnels.replaceCards([]));
    final betaCard = HostCardSsh.fromStored({
      ...host.hostCard!.stored,
      'name': 'beta',
      'services': {
        'forge': {'web_port': 19080, 'git_port': 19081},
        'matrix': {'port': 19082},
      },
    });
    final beta = Machine.fromHostCard(betaCard, socketPath: '${folder.path}/b');
    await Future<void>.sync(() => tunnels.registerCards([beta]));
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await raising, isTrue);
    await replacing;
    final gamma = Machine.fromHostCard(
      HostCardSsh.fromStored({...betaCard.stored, 'name': 'gamma'}),
      socketPath: '${folder.path}/g',
    );
    expect(() => tunnels.registerCards([gamma]), throwsA(isA<HostFilesRefused>()));
  });

  // Prevents a refused queued import from being saved before its reservation is checked.
  test('adding a card waits for queued reservation validation before saving it', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    final trial = tunnels.holdForTrial(host);
    addTearDown(() async {
      if (!checked.isCompleted) checked.complete(ProcessResult(0, 0, '', ''));
      await trial.release();
    });
    await entered.future;
    final changed = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'uid': 1002}),
      socketPath: '${folder.path}/changed',
      sshConfig: host.sshConfig,
    );
    final adding = machines.add(changed);
    final refused = expectLater(adding, throwsA(isA<HostFilesRefused>()));
    await Future<void>.delayed(Duration.zero);
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await trial.ready, isTrue);
    await refused;
    expect(machines.all, isNot(contains(changed)));
    expect(await settings.machines(), isNot(contains(changed)));
  });

  // Prevents a refused reservation replacement from leaving a listed machine without its fleet.
  for (final loading in [false, true]) {
    test('a refused ${loading ? 'loaded' : 'same-name'} replacement preserves the old fleet', () async {
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, tunnels: tunnels, reach: (_) => _StoppedBackend());
      addTearDown(machines.dispose);
      await machines.add(host);
      await machines.of(host).untilAsked();
      final services = {
        'forge': {'web_port': 19080, 'git_port': 19081},
        'matrix': {'port': 19082},
      };
      final beta = Machine.fromHostCard(
        HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta', 'services': services}),
        socketPath: '${folder.path}/b',
        sshConfig: '${folder.path}/porelo/ssh/beta.conf',
      );
      final trial = tunnels.holdForTrial(beta);
      addTearDown(trial.release);
      expect(await trial.ready, isTrue);
      final changed = Machine.fromHostCard(
        HostCardSsh.fromStored({...host.hostCard!.stored, 'services': services}),
        socketPath: '${folder.path}/changed',
        sshConfig: host.sshConfig,
      );
      if (loading) await settings.rememberMachines([changed]);
      await expectLater(loading ? machines.load() : machines.add(changed), throwsA(isA<HostFilesRefused>()));
      expect(machines.all, contains(host));
      expect(machines.all, isNot(contains(changed)));
      await machines.of(host).untilAsked();
      expect(tunnels.of(host)!.state, TunnelState.up, reason: 'the retained machine must regain a usable watcher');
      expect(processes.first.killed, isTrue);
      expect(processes[1].killed, isFalse, reason: 'the unsaved probe still owns its master');
    });
  }

  // Prevents a canceled handoff between probes from orphaning the old master.
  test('canceling a queued trial releases the master left for it by an earlier probe', () async {
    final alphaEntered = Completer<void>();
    final betaEntered = Completer<void>();
    final alphaCheck = Completer<ProcessResult>();
    final betaCheck = Completer<ProcessResult>();
    var checks = 0;
    checkControl = () {
      if (++checks == 1) {
        alphaEntered.complete();
        return alphaCheck.future;
      }
      betaEntered.complete();
      return betaCheck.future;
    };
    addTearDown(() {
      if (!alphaCheck.isCompleted) alphaCheck.complete(ProcessResult(0, 0, '', ''));
      if (!betaCheck.isCompleted) betaCheck.complete(ProcessResult(0, 0, '', ''));
    });
    final first = tunnels.holdForTrial(host);
    await alphaEntered.future;
    final releasingFirst = first.release();
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({
        ...host.hostCard!.stored,
        'name': 'beta',
        'services': {
          'forge': {'web_port': 19080, 'git_port': 19081},
          'matrix': {'port': 19082},
        },
      }),
      socketPath: '${folder.path}/b',
      sshConfig: '${folder.path}/porelo/ssh/beta.conf',
    );
    final watchingBeta = tunnels.raiseFor(beta);
    await betaEntered.future;
    final barrier = Future<void>.sync(() => tunnels.registerCards([host, beta]));
    final second = tunnels.holdForTrial(host);
    alphaCheck.complete(ProcessResult(0, 0, '', ''));
    expect(await first.ready, isTrue);
    await releasingFirst;
    expect(processes.first.killed, isFalse, reason: 'the queued trial still needs this master');
    final releasingSecond = second.release();
    betaCheck.complete(ProcessResult(0, 0, '', ''));
    expect(await watchingBeta, isTrue);
    await barrier;
    expect(await second.ready, isFalse);
    await releasingSecond;
    expect(processes.first.killed, isTrue, reason: 'the canceled handoff has no remaining consumer');
    expect(tunnels.manages(host), isFalse);
    expect(processes.last.killed, isFalse, reason: 'the unrelated watcher still needs its master');
  });

  // Prevents finishing an old teardown from deleting a new connection's endpoints or cancelling its unlock.
  for (final probe in [false, true]) {
    test('a new ${probe ? 'trial' : 'watcher'} waits for a releasing master to stop', () async {
      final old = _SlowProcess();
      nextProcess = () => processes.isEmpty ? old : _Process();
      final trial = tunnels.holdForTrial(host);
      expect(await trial.ready, isTrue);
      final releasing = trial.release();
      await old.stopping.future;
      final dropping = tunnels.dropFor(host);
      final candidate = probe ? tunnels.holdForTrial(host) : null;
      final joining = candidate?.ready ?? tunnels.raiseFor(host);
      addTearDown(() async {
        old.end('');
        await releasing;
        await dropping;
        await joining;
        await candidate?.release();
      });
      await Future<void>.delayed(Duration.zero);
      final beforeStop = launches.length;
      final checksBeforeStop = keyChecks;
      old.end('');
      await releasing;
      await dropping;
      expect(await joining, isTrue);
      expect(checksBeforeStop, 1, reason: 'new key and unlock work must wait for the old teardown');
      expect(beforeStop, 1, reason: 'a new master must wait until the old teardown finishes');
      expect(launches, hasLength(2));
      expect(processes.last.killed, isFalse, reason: 'the finishing drop must leave the new master alive');
      if (candidate != null) await candidate.release();
    });
  }

  // Prevents a forgotten watcher from starting an unowned master after its requested drop.
  test('dropping a queued watcher cancels its reconnect after trial teardown', () async {
    final old = _SlowProcess();
    nextProcess = () => processes.isEmpty ? old : _Process();
    final trial = tunnels.holdForTrial(host);
    expect(await trial.ready, isTrue);
    final releasing = trial.release();
    addTearDown(() async {
      old.end('');
      await releasing;
    });
    await old.stopping.future;
    final watching = tunnels.raiseFor(host);
    final dropping = tunnels.dropFor(host);
    old.end('');
    await releasing;
    await dropping;
    expect(await watching, isFalse, reason: 'the later drop canceled this watcher before it could start');
    expect(launches, hasLength(1));
    expect(tunnels.manages(host), isFalse);
  });

  // Prevents an old host teardown from deleting another endpoint's new shared control socket.
  test('another endpoint waits for the old master to stop before claiming its card', () async {
    final old = _SlowProcess();
    nextProcess = () => processes.isEmpty ? old : _Process();
    final trial = tunnels.holdForTrial(host);
    expect(await trial.ready, isTrue);
    final releasing = trial.release();
    await old.stopping.future;
    final other = host.withSocketPath('${folder.path}/second');
    var joined = false;
    final joining = tunnels.raiseFor(other).then((ready) {
      joined = true;
      return ready;
    });
    addTearDown(() async {
      old.end('');
      await releasing;
      await joining;
    });
    await Future<void>.delayed(Duration.zero);
    expect(joined, isFalse, reason: 'the new request must wait while the old master owns the control socket');
    expect(launches, hasLength(1));
    old.end('');
    await releasing;
    expect(await joining, isTrue);
    expect(launches, hasLength(2));
    expect(processes.last.killed, isFalse, reason: 'old cleanup must leave the new master alive');
  });

  // Prevents an unused imported card from permanently blocking another host's fixed service ports.
  for (final replace in [false, true]) {
    test('dropping a ${replace ? 'replaced' : 'registered'} card before its first raise frees its ports', () async {
      if (replace) {
        tunnels.replaceCards([host]);
      } else {
        tunnels.registerCards([host]);
      }
      final beta = Machine.fromHostCard(
        HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
        socketPath: '${folder.path}/b',
      );
      expect(() => tunnels.registerCards([beta]), throwsA(isA<HostFilesRefused>()));
      await tunnels.dropFor(host.withSocketPath('${folder.path}/other'));
      expect(() => tunnels.registerCards([beta]), throwsA(isA<HostFilesRefused>()));
      await tunnels.dropFor(host);
      expect(() => tunnels.registerCards([beta]), returnsNormally);
      expect(launches, isEmpty, reason: 'reservation cleanup must not start SSH');
    });
  }

  // Prevents a candidate probe from closing a master promoted to a watched connection.
  test('watching a candidate promotes its master beyond the probe lifetime', () async {
    final backend = _PausedBackend();
    final trial = tryAMachine(host, reach: (_) => backend, tunnels: tunnels);
    await backend.entered.future;
    expect(await tunnels.raiseFor(host), isTrue);
    backend.finish.complete();
    await trial;
    expect(processes.single.killed, isFalse);
    expect(tunnels.manages(host), isTrue);
  });

  // Prevents concurrent imports from invalidating a replacement after its old watcher was closed.
  test('replacing a watched card waits for its active probe before releasing old ownership', () async {
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.add(host);
    await machines.of(host).untilAsked();
    final backend = _PausedBackend();
    final trial = tryAMachine(host, reach: (_) => backend, tunnels: tunnels);
    await backend.entered.future;
    final changed = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'uid': 1002}),
      socketPath: '${folder.path}/changed',
      sshConfig: host.sshConfig,
    );
    var replaced = false;
    final replacing = machines.add(changed).then((_) {
      replaced = true;
    });
    addTearDown(() async {
      if (!backend.finish.isCompleted) backend.finish.complete();
      await trial;
      await replacing;
    });
    await Future<void>.delayed(Duration.zero);
    expect(replaced, isFalse);
    backend.finish.complete();
    await trial;
    await replacing;
    await machines.of(changed).untilAsked();
    expect(processes.first.killed, isTrue);
    expect(tunnels.of(changed)!.state, TunnelState.up);
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(() => tunnels.registerCards([beta]), throwsA(isA<HostFilesRefused>()));
  });

  test('a replacement reserves its new ports before a concurrent import can claim them', () async {
    final master = _SlowProcess();
    var started = false;
    final owned = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      start: (_) async {
        if (started) return _Process();
        started = true;
        return master;
      },
      run: (_) async => ProcessResult(0, 0, '', ''),
      unlocker: unlock,
    );
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: owned, reach: (_) => _StoppedBackend());
    addTearDown(() async {
      master.end('');
      machines.dispose();
      await owned.dropEverything();
      owned.dispose();
    });
    await machines.add(host);
    await machines.of(host).untilAsked();
    final services = {
      'forge': {'web_port': 19080, 'git_port': 19081},
      'matrix': {'port': 19082},
    };
    final changed = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'services': services}),
      socketPath: '${folder.path}/changed',
      sshConfig: host.sshConfig,
    );
    final replacing = machines.add(changed);
    await master.stopping.future;
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta', 'services': services}),
      socketPath: '${folder.path}/beta',
    );
    final adding = machines.add(beta);
    final refused = expectLater(adding, throwsA(isA<HostFilesRefused>()));
    master.end('');
    await replacing;
    await refused;
    expect(machines.all, contains(changed));
    expect(machines.all, isNot(contains(beta)));
    expect(machines.of(changed), isNotNull);
  });

  test('replacing a card drops its old master and accepts its changed admitted uid', () async {
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.add(host);
    await machines.of(host).untilAsked();
    final old = processes.single;
    final changed = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'uid': 1002}),
      socketPath: '${folder.path}/new',
      sshConfig: host.sshConfig,
    );
    await machines.add(changed);
    expect(old.killed, isTrue);
    expect(machines.all, contains(changed));
  });

  // Prevents an ignored same-name import from reserving ports against later valid imports.
  test('an ignored replacement does not reserve its card ports', () async {
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.add(Machine(name: host.name, socketPath: '${folder.path}/local'));
    await machines.add(host);
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(() => tunnels.registerCards([beta]), returnsNormally);
  });

  // Prevents loading a new watched list from orphaning masters and stale imported port reservations.
  test('loading another list stops old tunnels and releases old cards', () async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.add(host);
    await machines.of(host).untilAsked();
    await settings.rememberMachines([Machine(name: 'replacement', socketPath: '${folder.path}/replacement')]);
    await machines.load();
    expect(processes.single.killed, isTrue);
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(() => tunnels.registerCards([beta]), returnsNormally);
  });

  // Prevents a signing wait on an SSH-reached host from being counted as a host outage.
  test('a reached host waiting for Core signing is excluded from unreachable hosts', () async {
    unlock.result = const HostUnlockResult(HostUnlockState.waitingForKey);
    final settings = Settings(MemorySettingsStore());
    await settings.rememberMachines([host]);
    final machines = Machines(settings, tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.load();
    await machines.of(host).untilAsked();
    await Future<void>.delayed(Duration.zero);
    expect(machines.all, [host]);
    expect(machines.of(host).reachability, Reachability.unreachable);
    expect(machines.of(host).hostReachability, HostReachability.waitingForKey);
    expect(machines.unreachable, 0);
  });

  // Prevents an in-flight raise failure from abandoning later owned processes during shutdown.
  test('shutdown cleans every master after an in-flight raise rejects', () async {
    final entered = Completer<void>();
    final check = Completer<ProcessResult>();
    final process = _Process();
    final owned = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      start: (_) async => process,
      run: (_) {
        entered.complete();
        return check.future;
      },
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
    );
    addTearDown(owned.dispose);
    final raising = owned.raiseFor(host);
    final observed = expectLater(raising, throwsStateError);
    await entered.future;
    final dropping = owned.dropEverything();
    final cleanup = expectLater(dropping, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    check.completeError(StateError('control check failed'));
    await observed;
    await cleanup;
    expect(process.killed, isTrue);
    expect(owned.manages(host), isFalse);
  });

  // Prevents window shutdown from leaving Core signing or secret delivery running.
  test('shutdown cancels an active Core unlock before waiting for the host queue', () async {
    final entered = Completer<void>();
    final coreProcess = _Process();
    final master = _Process();
    final core = CoreHostUnlocker(
      environment: {'XDG_CONFIG_HOME': folder.path},
      start: (_) async {
        entered.complete();
        return coreProcess;
      },
    );
    final owned = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      run: (_) async => ProcessResult(0, 0, '', ''),
      start: (_) async => master,
      unlocker: core,
    );
    addTearDown(() async {
      coreProcess.end('');
      await owned.dropEverything();
      owned.dispose();
    });
    final raising = owned.raiseFor(host);
    await entered.future;
    final dropping = owned.dropEverything();
    await Future<void>.delayed(Duration.zero);
    final canceledBeforeSettling = coreProcess.killed;
    coreProcess.end('');
    await raising;
    await dropping;
    expect(canceledBeforeSettling, isTrue, reason: 'shutdown must interrupt Core without waiting for its deadline');
    expect(master.killed, isTrue);
    expect(owned.manages(host), isFalse);
  });

  // Prevents an SSH unlink race from interrupting shutdown before all masters are stopped.
  test('shutdown tolerates a disappearing owned socket', () async {
    await tunnels.raiseFor(host);
    final endpoint = host.socketPath;
    var checked = false;
    await IOOverrides.runZoned(
      tunnels.dropEverything,
      fseGetTypeSync: (path, followLinks) {
        if (path == endpoint && !checked) {
          checked = true;
          return FileSystemEntityType.unixDomainSock;
        }
        return FileSystemEntityType.notFound;
      },
    );
    expect(processes.single.killed, isTrue);
    expect(tunnels.manages(host), isFalse);
  });

  test('publishes a pinned public identity and launches all fixed forwards on one owned master', () async {
    expect(await tunnels.raiseFor(host), isTrue);
    final config = File(host.sshConfig).readAsStringSync();
    expect(config, contains('Host alpha\n'));
    expect(config, contains('HostName alpha.example.org'));
    expect(config, contains('Port 2222'));
    expect(config, contains('User alice'));
    for (final policy in [
      'StrictHostKeyChecking yes',
      'IdentitiesOnly yes',
      'ForwardAgent no',
      'GlobalKnownHostsFile none',
      'KnownHostsCommand none',
      'VerifyHostKeyDNS no',
      'UpdateHostKeys no',
    ]) {
      expect(config, contains(policy), reason: 'missing pinned policy $policy');
    }
    expect(File('${host.sshConfig}.pub').readAsStringSync(), '$publicKey\n');
    expect(File('${host.sshConfig}.known_hosts').readAsStringSync(), '[alpha.example.org]:2222 $publicKey\n');
    for (final file in [host.sshConfig, '${host.sshConfig}.pub', '${host.sshConfig}.known_hosts']) {
      expect(FileStat.statSync(file).mode & 0x1ff, 0x180, reason: 'public transport files remain owner-only');
    }
    final command = launches.single;
    expect(command.take(5), ['ssh', '-F', host.sshConfig, '-M', '-N']);
    expect(command, contains('ExitOnForwardFailure=yes'));
    final forwards = [
      for (var i = 0; i < command.length - 1; i++)
        if (command[i] == '-L') command[i + 1],
    ];
    expect(forwards, [
      '127.0.0.1:18080:/run/porelo-forge/web.sock',
      '127.0.0.1:18081:/run/porelo-forge/git.sock',
      '127.0.0.1:18082:/run/porelo-matrix/client.sock',
      '${host.socketPath}:/run/user/1001/porelo/porelod.sock',
    ]);
    expect(command.where((word) => word == '-R'), hasLength(1));
    expect(command[command.indexOf('-R') + 1], '${host.hostCard!.returnSocket}:${folder.path}/m');
    expect(command, isNot(contains('-A')));
    expect(unlock.calls, [('alpha', host.sshConfig)]);
    expect(host.stored, isNot(contains('identity')));
    expect(host.hostCard!.forgeUrl, 'http://alpha.localhost:18080/');
    expect(host.hostCard!.matrixUrl, 'http://alpha.localhost:18082/');
  });

  // Prevents account commands from bypassing the pin or disabling the host's shared master.
  test('card account logins retain the effective pin and shared control socket', () async {
    await host.hostCard!.publish(host.sshConfig, environment: {'XDG_CONFIG_HOME': folder.path});
    final session = Session(
      task: 'task',
      machine: host,
      open: (exe, args, {columns = 80, rows = 24}) => FakeTerminal([exe, ...args]),
    );
    addTearDown(session.dispose);
    final commands = <String, List<String>>{
      'terminal': session.command,
      'forward': loginForwardCommand(host, 42017),
      'command': onTheMachine(host, ['true'], terminal: false)!,
      'interactive command': onTheMachine(host, ['true'], terminal: true)!,
      'written command': onTheMachineAsWritten(host, 'true')!,
      'start daemon': Tunnels.startCommandFor(host),
      'stop daemon': Tunnels.stopCommandFor(host),
      'uid': Tunnels.loginUidCommandFor(host),
    };
    for (final entry in commands.entries) {
      final result = await Process.run(entry.value.first, ['-G', ...entry.value.skip(1)]);
      expect(result.exitCode, 0, reason: '${entry.key}: ${result.stderr}');
      expect(
        result.stdout.toString().split('\n'),
        containsAll([
          'hostname alpha.example.org',
          'port 2222',
          'user alice',
          'stricthostkeychecking true',
          'userknownhostsfile ${host.sshConfig}.known_hosts',
          'globalknownhostsfile none',
          'batchmode yes',
          'forwardagent no',
          'identitiesonly yes',
          'identityfile ${host.sshConfig}.pub',
          'controlmaster false',
          'controlpath ${host.hostCard!.controlSocket(host.sshConfig)}',
        ]),
        reason: '${entry.key} must reuse the pinned card transport',
      );
      expect(entry.value, isNot(contains('-i')), reason: entry.key);
    }
  });

  // Prevents importing a card from bypassing recovery of an obsolete billed host.
  test('a legacy rental refuses its card transport before any launch', () async {
    final legacy = Machine.fromStored(host.stored, legacyHost: true).withSocketPath(host.socketPath);
    expect(legacy.legacyHost, isTrue);
    expect(legacy.hostCard!.stored, host.hostCard!.stored);
    expect(legacy.sshConfig, host.sshConfig);
    expect(legacy.whyNotReachableOn(windows: false), isNotNull);
    expect(legacy.whyNotReachableOn(windows: true), isNotNull);
    expect(await tunnels.raiseFor(legacy), isFalse);
    expect(launches, isEmpty);
    expect(File(host.sshConfig).existsSync(), isFalse);
    expect(legacy, isNot(host), reason: 'recovery state changes whether an otherwise identical machine can connect');
  });

  // Prevents concurrent project joins from launching duplicate masters or repeating unlock.
  test('concurrent joins and commands reuse one connection', () async {
    final results = await Future.wait([tunnels.raiseFor(host), tunnels.raiseFor(host), tunnels.raiseFor(host)]);
    expect(results, everyElement(isTrue));
    expect(launches, hasLength(1));
    expect(unlock.calls, hasLength(1));
    await tunnels.startPoreloOn(host);
    expect(runs.last, containsAllInOrder(['-F', host.sshConfig, 'ControlMaster=no', 'ProxyCommand=false']));
    expect(launches, hasLength(1));
  });

  // Prevents Matrix joining from creating a second SSH process or closing the host master.
  test('Matrix projects use the shared fixed port and leave its owner alive on disposal', () async {
    final forwards = HomeserverForwards(
      Settings(MemorySettingsStore()),
      tunnels: tunnels,
      raise: (_, _) => throw StateError('a card must never raise a separate Matrix tunnel'),
    );
    await forwards.hold(host, 'one', 18082);
    await forwards.hold(host, 'two', 18082);
    expect(forwards.portOf(host, 'one'), 18082);
    expect(launches, hasLength(1));
    forwards.dispose();
    expect(processes.single.killed, isFalse);
    await expectLater(forwards.hold(host, 'wrong', 18083), throwsA(isA<ForwardRefused>()));
  });

  // Prevents a stopped daemon from being mistaken for SSH failure or dropping the shared master.
  test('a stopped daemon remains a reached host and a trial leaves the master alive', () async {
    await tunnels.raiseFor(host);
    final backend = _StoppedBackend();
    final model = FleetModel(
      backend,
      hostConnection: () =>
          tunnels.of(host)?.state == TunnelState.up ? HostReachability.reached : HostReachability.notReached,
    );
    addTearDown(model.dispose);
    await model.connect();
    expect(model.reachability, Reachability.unreachable);
    expect(model.hostReachability, HostReachability.reached);
    final trial = await tryAMachine(host, reach: (_) => backend, tunnels: tunnels);
    expect(trial.nothingServing, isTrue);
    expect(processes.single.killed, isFalse);
    expect(launches, hasLength(1));
  });

  // Prevents silently changing fixed endpoints after a network drop.
  test('reconnect preserves the fixed endpoints and closing kills only owned processes', () async {
    await tunnels.raiseFor(host);
    processes.single.end('Connection closed');
    await Future<void>.delayed(Duration.zero);
    await tunnels.raiseAgainIfItDropped(host);
    expect(launches, hasLength(2));
    expect(launches[1], launches[0]);
    final unrelated = File('${folder.path}/unrelated')..writeAsStringSync('leave alone');
    await tunnels.dropEverything();
    expect(processes.every((process) => process.killed || process.ended), isTrue);
    expect(unrelated.readAsStringSync(), 'leave alone');
    expect(tunnels.manages(host), isFalse);
  });

  // Prevents reporting denied admission as a locked local key.
  test('an unavailable local key waits without launching or unlocking', () async {
    final waiting = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => false,
      portsAvailable: (_) async {},
      unlocker: unlock,
      start: (_) => throw StateError('a locked key must not launch SSH'),
    );
    addTearDown(waiting.dispose);
    expect(await waiting.raiseFor(host), isFalse);
    expect(waiting.of(host)!.state, TunnelState.waitingForKey);
    expect(unlock.calls, isEmpty);
    expect(File(host.sshConfig).existsSync(), isFalse);
    await waiting.dropEverything();
  });

  // Prevents connecting or unlocking against a changed host key.
  test('a pin mismatch fails before unlock without exposing process diagnostics', () async {
    final refused = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
      run: (_) async => ProcessResult(0, 1, '', ''),
      start: (_) async {
        final process = _Process();
        process.end('Host key verification failed.');
        return process;
      },
    );
    addTearDown(refused.dispose);
    expect(await refused.raiseFor(host), isFalse);
    expect(refused.of(host)!.state, TunnelState.down);
    expect(refused.of(host)!.problem, contains('key'));
    expect(unlock.calls, isEmpty);
    await refused.dropEverything();
  });

  // Prevents vault refusal from relabeling an SSH-reached host as unavailable.
  test('Core vault refusal remains separate from successful transport', () async {
    unlock.result = const HostUnlockResult(HostUnlockState.refused, 'The host vault refused unlock.');
    expect(await tunnels.raiseFor(host), isTrue);
    expect(tunnels.of(host)!.vaultProblem, 'The host vault refused unlock.');
    expect(tunnels.of(host)!.problem, isNull);
  });

  // Prevents persistence from losing the selected public identity or saving conflicting hosts.
  test('settings retain public card references and reject conflicting imports before replacing the list', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    await settings.rememberMachines([host]);
    final restored = (await settings.machines()).single;
    expect(restored.hostCard!.stored, host.hostCard!.stored);
    expect(restored.sshConfig, host.sshConfig);
    expect(restored.identity, isEmpty);
    expect(restored, host, reason: 'restoring a public card must preserve machine identity');
    final conflict = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
      sshConfig: '${folder.path}/beta.conf',
    );
    await expectLater(settings.rememberMachines([host, conflict]), throwsA(isA<HostFilesRefused>()));
    expect((await settings.machines()).map((machine) => machine.name), ['alpha']);
  });

  // Prevents a hung SSH control check from keeping an owned process alive indefinitely.
  test('a stalled control check is bounded and stops its master', () async {
    final check = Completer<ProcessResult>();
    final process = _Process();
    final tunnel = Tunnel(
      host,
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
      start: (_) async => process,
      run: (_) => check.future,
      appears: const Duration(milliseconds: 50),
      explains: const Duration(milliseconds: 20),
    );
    addTearDown(() async {
      if (!check.isCompleted) check.complete(ProcessResult(0, 1, '', ''));
      await tunnel.drop();
    });
    await tunnel.raise().timeout(const Duration(milliseconds: 400));
    expect(tunnel.state, TunnelState.down);
    expect(process.killed, isTrue);
    expect(unlock.calls, isEmpty);
  });

  // Prevents a cancelled unlock from surviving the window and acting after a reconnect.
  test('dropping the tunnel cancels Core unlock as well as the SSH master', () async {
    final asked = Completer<void>();
    final core = _Process();
    final master = _Process();
    final coreUnlock = CoreHostUnlocker(
      environment: {'XDG_CONFIG_HOME': folder.path},
      start: (_) async {
        asked.complete();
        return core;
      },
    );
    final tunnel = Tunnel(
      host,
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: coreUnlock,
      start: (_) async => master,
      run: (_) async => ProcessResult(0, 0, '', ''),
    );
    final raising = tunnel.raise();
    addTearDown(() async {
      core.end('');
      await raising;
      await tunnel.drop();
    });
    await asked.future;
    await tunnel.drop();
    expect(core.killed, isTrue, reason: 'Core unlock must be owned and cancelled with the transport');
    expect(master.killed, isTrue);
  });

  // Prevents UI operations from reaching an unrelated endpoint after transport refusal.
  test('a refused card transport gates initial daemon opens and later reconnects', () async {
    final denied = Tunnels(keyAvailable: (_) async => false, portsAvailable: (_) async {});
    final backend = _StoppedBackend();
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: denied, reach: (_) => backend);
    addTearDown(() async {
      machines.dispose();
      await denied.dropEverything();
      denied.dispose();
    });
    await machines.add(host);
    await machines.of(host).untilAsked();
    final opened = backend.opened;
    await machines.of(host).connect();
    await machines.of(host).refresh();
    expect(backend.opened, opened, reason: 'retries must not bypass the refused transport');
    expect(opened, 1, reason: 'only the initial non-card local machine may open a backend');
  });

  // Prevents a transient vault refusal from persisting forever on a healthy SSH connection.
  test('retrying a refused vault unlock retains its master and clears the refusal', () async {
    unlock.result = const HostUnlockResult(HostUnlockState.waitingForKey, 'Unlock the local key.');
    await tunnels.raiseFor(host);
    expect(tunnels.of(host)!.vaultProblem, isNotNull);
    unlock.result = const HostUnlockResult(HostUnlockState.unlocked);
    await tunnels.raiseFor(host);
    expect(unlock.calls, hasLength(2));
    expect(launches, hasLength(1));
    expect(tunnels.of(host)!.vaultProblem, isNull);
  });

  // Prevents a timed-out Core child from remaining alive or exposing its output.
  test('Core refuses an off-platform config before launching unlock', () async {
    final commands = <List<String>>[];
    final core = CoreHostUnlocker(
      environment: {'XDG_CONFIG_HOME': folder.path},
      start: (command) async {
        commands.add(command);
        final process = _Process();
        process.end('');
        return process;
      },
    );
    final result = await core.unlock('alpha', '${folder.path}/alpha.conf');
    expect(commands, isEmpty);
    expect(result.state, HostUnlockState.refused);
  });

  test('Core unlock uses the agreed command and terminates its child on deadline', () async {
    final process = _Process();
    final commands = <List<String>>[];
    final core = CoreHostUnlocker(
      environment: {'XDG_CONFIG_HOME': folder.path},
      deadline: const Duration(milliseconds: 20),
      start: (command) async {
        commands.add(command);
        return process;
      },
    );
    final result = await core.unlock('alpha', host.sshConfig);
    expect(commands, [
      ['porelo', 'host', 'unlock', 'alpha'],
    ]);
    expect(process.killed, isTrue);
    expect(result.state, HostUnlockState.refused);
    expect(result.words, 'Core host unlock timed out.');
  });

  // Prevents a busy service port from producing a misleading usable host or public config.
  test('a busy fixed port prevents config publication and SSH launch', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final card = HostCardSsh.fromStored({
      ...host.hostCard!.stored,
      'services': {
        'forge': {'web_port': occupied.port, 'git_port': occupied.port == 18081 ? 18084 : 18081},
        'matrix': {'port': occupied.port == 18082 ? 18085 : 18082},
      },
    });
    final busyHost = Machine.fromHostCard(card, socketPath: host.socketPath, sshConfig: host.sshConfig);
    final busy = Tunnels(
      keyAvailable: (_) async => true,
      unlocker: unlock,
      start: (_) => throw StateError('a busy fixed port must not launch SSH'),
    );
    addTearDown(() async {
      await busy.dropEverything();
      busy.dispose();
    });
    expect(await busy.raiseFor(busyHost), isFalse);
    expect(busy.of(busyHost)!.problem, contains('${occupied.port}'));
    expect(File(host.sshConfig).existsSync(), isFalse);
    expect(unlock.calls, isEmpty);
  });

  // Prevents shutdown from deleting an existing forward this interface refused to replace.
  test('a preexisting daemon endpoint survives refused card transport and shutdown', () async {
    final server = await ServerSocket.bind(InternetAddress(host.socketPath, type: InternetAddressType.unix), 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());
    expect(await tunnels.raiseFor(host), isFalse);
    expect(launches, isEmpty);
    await tunnels.dropEverything();
    final connection = await Socket.connect(InternetAddress(host.socketPath, type: InternetAddressType.unix), 0);
    connection.destroy();
    expect(FileSystemEntity.typeSync(host.socketPath), FileSystemEntityType.unixDomainSock);
  });

  // Prevents a real stand-in process and its owned Unix endpoints from surviving shutdown.
  test('shutdown removes both owned sockets and the SSH stand-in process', () async {
    Process? child;
    final control = host.hostCard!.controlSocket(host.sshConfig);
    final owned = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
      start: (command) async {
        final at = command.indexOf('-L');
        final daemon = command
            .skip(at)
            .where((value) => value.startsWith('${host.socketPath}:'))
            .single
            .split(':')
            .first;
        child = await Process.start('python3', [
          '-c',
          'import socket,sys,time,os; os.umask(0o177); '
              'a=socket.socket(socket.AF_UNIX); a.bind(sys.argv[1]); a.listen(1); '
              'b=socket.socket(socket.AF_UNIX); b.bind(sys.argv[2]); b.listen(1); time.sleep(300)',
          daemon,
          control,
        ]);
        return child!;
      },
      run: (_) async =>
          ProcessResult(0, FileSystemEntity.typeSync(control) == FileSystemEntityType.unixDomainSock ? 0 : 1, '', ''),
    );
    addTearDown(() async {
      await owned.dropEverything();
      owned.dispose();
    });
    expect(await owned.raiseFor(host), isTrue);
    expect(FileSystemEntity.typeSync(host.socketPath), FileSystemEntityType.unixDomainSock);
    expect(FileStat.statSync(host.socketPath).mode & 0x1ff, 0x180);
    await owned.dropEverything();
    await child!.exitCode.timeout(const Duration(seconds: 1));
    expect(FileSystemEntity.typeSync(host.socketPath), FileSystemEntityType.notFound);
    expect(FileSystemEntity.typeSync(control), FileSystemEntityType.notFound);
  });
}

class _Unlock implements HostUnlocker {
  final calls = <(String, String)>[];
  HostUnlockResult result = const HostUnlockResult(HostUnlockState.unlocked);
  @override
  Future<HostUnlockResult> unlock(String host, String config) async {
    calls.add((host, config));
    return result;
  }

  @override
  Future<void> cancel(String host) async {}
}

class _Process extends Fake implements Process {
  final _exit = Completer<int>();
  final _errors = StreamController<List<int>>();
  bool killed = false;
  bool get ended => _exit.isCompleted;
  void end(String words) {
    if (ended) return;
    _errors.add(utf8.encode(words));
    unawaited(_errors.close());
    _exit.complete(255);
  }

  @override
  Stream<List<int>> get stderr => _errors.stream;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    end('');
    return true;
  }
}

class _StoppedBackend extends Fake implements FleetBackend {
  int opened = 0;
  @override
  String get label => 'alpha';
  @override
  Future<ServiceInfo> open() async {
    opened++;
    throw const VarlinkDisconnected('The daemon is stopped.');
  }
}

class _PausedBackend extends _StoppedBackend {
  final entered = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<ServiceInfo> open() async {
    entered.complete();
    await finish.future;
    return super.open();
  }
}

class _SlowProcess extends _Process {
  final stopping = Completer<void>();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!stopping.isCompleted) stopping.complete();
    return true;
  }
}

class _FailingStopProcess extends _Process {
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    super.kill(signal);
    throw StateError('the old process stop failed');
  }
}
