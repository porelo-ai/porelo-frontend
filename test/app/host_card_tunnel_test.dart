// Linux only: private config publication uses chmod and Unix control sockets.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/homeserver_forwards.dart';
import 'package:porelo_frontend/src/app/login_forward.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/person_only_relay.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/ssh_words.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart' show machineRowWords;
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeTerminal;
import '../support/other_sockets.dart';

const publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const hostKeyFingerprint = 'SHA256:kmYcvdi2GkPeWxB6XLjrZB8JHsy2Hm8luHMFp9GMvqk';

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
    // This account's alone, as the runtime directory is: the one place a socket the window made is later removed.
    Process.runSync('chmod', <String>['700', folder.path]);
    final card = HostCardSsh(
      name: 'alpha',
      address: 'alpha.example.org',
      sshPort: 2222,
      hostKey: publicKey,
      login: 'alice',
      publicKey: publicKey,
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

  // Harm: ssh told by the card's config to unlink before binding deletes whatever is at the socket path.
  test("the card's ssh never unlinks what is at the socket path before binding, whatever its config says", () async {
    File(host.sshConfig)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('Host *\n  StreamLocalBindUnlink yes\n');
    final command = Tunnel(host).command;

    final effective = await Process.run(command.first, <String>['-G', ...command.skip(1)]);

    expect(effective.exitCode, 0, reason: '${effective.stderr}');
    expect('${effective.stdout}'.split('\n'), contains('streamlocalbindunlink no'));
  });

  // Prevents SSH from using personal trust, another identity or externally bound services.
  // Guards a card host the IDE plugin, which reads the same file, would drop as of an unknown kind.
  test('a card host is stored without a kind and read back as a host', () {
    final stored = host.stored;

    expect(stored.containsKey('kind'), isFalse, reason: 'the plugin shows an entry with a kind as not reached');
    expect(stored['host'], 'alpha');
    expect(stored['remoteSocket'], host.remoteSocket);
    expect(stored['socket'], host.socketPath);
    expect(Machine.fromStored(stored).kind, 'host');
  });

  // Harm: a host watched before its daemon was linked under the login is lost, forwards a socket the host no longer
  // serves, or is saved again with it for the plugin to read; one card that no longer reads loses every machine.
  test('older card records are loaded, saved in today\'s form, and one that does not read is set aside', () async {
    Map<String, Object?> record(String name, int port, Map<String, Object?> card, {String? remoteSocket}) => {
      ...host.stored,
      'name': name,
      'host': name,
      'socket': '${folder.path}/$name',
      'sshConfig': '${folder.path}/porelo/ssh/$name.conf',
      'remoteSocket': ?remoteSocket,
      'hostCard': {
        ...host.hostCard!.stored,
        'name': name,
        'services': {
          'forge': {'web_port': port, 'git_port': port + 1},
          'matrix': {'port': port + 2},
        },
        ...card,
      },
    };
    final unreadable = record('gamma', 18090, {'login': 'porelo_alice'});
    final store = MemorySettingsStore({
      'machines': [
        record('alpha', 18080, {
          'uid': 1001,
          'return_socket': '/run/porelo-host/people/alice/messenger.sock',
        }, remoteSocket: '/run/user/1001/porelo/porelod.sock'),
        unreadable,
        record('beta', 18084, {
          'return_socket': '/run/porelo-host/people/alice/messenger.sock',
        }, remoteSocket: '/run/porelo-host/alice/porelod.sock'),
        record('delta', 18094, {}, remoteSocket: '/run/user/1001/porelo/porelod.sock'),
        // A socket of an older layout, with neither uid nor return socket.
        record('epsilon', 18098, {}, remoteSocket: '/run/porelo-host/alice/porelod.sock'),
      ],
    });
    final settings = Settings(store);
    await settings.load();
    final machines = Machines(settings, reach: (_) => _StoppedBackend(), tunnels: tunnels);
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    await machines.load();
    final cards = machines.all.where((machine) => machine.hostCard != null).toList();
    expect(cards.map((machine) => machine.name), ['alpha', 'beta', 'delta', 'epsilon']);
    for (final machine in cards) {
      expect(machine.remoteSocket, '/run/porelo-host/people/alice/porelod.sock', reason: machine.name);
      expect(machine.whyNotReachableOn(windows: false), isNull, reason: machine.name);
    }
    expect(machines.setAside, contains('gamma'));
    // Said under Needs you, where it stays, never on a status line the restored machine's connection overwrites.
    final attention = Attention(machines);
    addTearDown(attention.dispose);
    expect(
      attention.openRows.where((row) => row.kind == AttentionKind.setAside).single.value,
      allOf(contains('gamma'), contains('not watched')),
    );
    final saved = (await store.read())['machines'] as List;
    expect(saved, contains(unreadable), reason: 'what did not read stays saved as it was');
    for (final entry in saved.cast<Map<String, Object?>>().where((entry) => entry['name'] != 'gamma')) {
      expect(entry['remoteSocket'], '/run/porelo-host/people/alice/porelod.sock', reason: '${entry['name']}');
      expect(entry['hostCard'], isNot(anyOf(contains('uid'), contains('return_socket'))), reason: '${entry['name']}');
    }
  });

  // Harm: a notice that only informs can never be put away, comes back at every start, or once seen hides machines
  // set aside later.
  test('the notice of machines set aside is seen until the machines set aside change', () async {
    Map<String, Object?> unreadable(String name) => {
      ...host.stored,
      'name': name,
      'host': name,
      'socket': '${folder.path}/$name',
      'sshConfig': '${folder.path}/porelo/ssh/$name.conf',
      'hostCard': {...host.hostCard!.stored, 'name': name, 'login': 'porelo_alice'},
    };
    final store = MemorySettingsStore({
      'machines': [unreadable('gamma')],
    });
    Future<List<AttentionRow>> notices({void Function(Attention attention)? then}) async {
      final settings = Settings(store);
      await settings.load();
      final machines = Machines(settings, reach: (_) => _StoppedBackend(), tunnels: tunnels);
      await machines.load();
      final attention = Attention(machines, settings);
      then?.call(attention);
      await pumpEventQueue();
      final rows = attention.openRows.where((row) => row.kind == AttentionKind.setAside).toList();
      attention.dispose();
      machines.dispose();
      settings.dispose();
      return rows;
    }

    expect(await notices(then: (attention) => attention.setAsideSeen()), isEmpty, reason: 'seen');
    expect(await notices(), isEmpty, reason: 'seen stays seen past a restart');
    await store.write({
      ...await store.read(),
      'machines': [unreadable('gamma'), unreadable('zeta')],
    });
    expect(await notices(), hasLength(1), reason: 'another machine set aside is another notice');
  });

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

  // Harm: a master whose configuration was removed keeps its endpoints, and the host can never be raised again.
  test('a master left without its configuration is ended, and the host is raised again', () async {
    final card = host.hostCard!;
    final control = card.controlSocket(host.sshConfig);
    Directory(File(control).parent.path).createSync(recursive: true);
    final orphan = await ServerSocket.bind(InternetAddress(control, type: InternetAddressType.unix), 0);
    final forward = await ServerSocket.bind(InternetAddress(host.socketPath, type: InternetAddressType.unix), 0);
    checkControl = () async {
      if (runs.last.contains('exit')) {
        await orphan.close();
        await forward.close();
      }
      return ProcessResult(0, 0, '', '');
    };
    expect(await tunnels.raiseFor(host), isTrue, reason: tunnels.of(host)?.problem);
    expect(runs.first, ['ssh', '-F', '/dev/null', '-o', 'ControlPath=$control', '-O', 'exit', 'alpha']);
    expect(launches, hasLength(1));
  });

  // Harm: after a restart of the interface, its own earlier master refuses the host until it is ended by hand.
  for (final same in [true, false]) {
    test('a master no tunnel here started, configured for ${same ? 'this' : 'another'} login, is '
        '${same ? 'ended and the host raised' : 'left alone'}', () async {
      final card = host.hostCard!;
      final control = card.controlSocket(host.sshConfig);
      Directory(File(control).parent.path).createSync(recursive: true);
      // The configuration as the earlier run published it, for this card's login or another's.
      await (same ? card : HostCardSsh.fromStored({...card.stored, 'login': 'someone-else'})).publish(
        host.sshConfig,
        environment: {'XDG_CONFIG_HOME': folder.path},
      );
      final left = await ServerSocket.bind(InternetAddress(control, type: InternetAddressType.unix), 0);
      addTearDown(() => left.close());
      checkControl = () async {
        if (runs.last.contains('exit')) await left.close();
        return ProcessResult(0, 0, '', '');
      };
      expect(await tunnels.raiseFor(host), same, reason: tunnels.of(host)?.problem);
      expect(runs.where((run) => run.contains('exit')), same ? hasLength(1) : isEmpty);
      expect(launches, same ? hasLength(1) : isEmpty);
    });
  }

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

  // Prevents an automatic retry from orphaning a trial-only master and its ports.
  test('a retry queued after trial release cannot keep the trial master alive', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final trial = tunnels.holdForTrial(host);
    await entered.future;
    final releasing = trial.release();
    final retrying = tunnels.raiseAgainIfItDropped(host);
    checkControl = null;
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await trial.ready, isTrue);
    await releasing;
    await retrying;
    expect(processes.single.killed, isTrue, reason: 'retry is not a new consumer of an unwatched card');
    expect(tunnels.manages(host), isFalse);
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(() => tunnels.registerCards([beta]), returnsNormally);
  });

  // Prevents retry from promoting a dropped probe into a permanent watcher.
  test('a retry of a dropped trial does not retain or restart its master', () async {
    final trial = tunnels.holdForTrial(host);
    expect(await trial.ready, isTrue);
    processes.single.end('Connection closed');
    await Future<void>.delayed(Duration.zero);
    await tunnels.raiseAgainIfItDropped(host);
    await trial.release();
    expect(launches, hasLength(1), reason: 'only a watcher may reconnect automatically');
    expect(tunnels.manages(host), isFalse);
  });

  // Prevents replacement from proceeding while the old trial master still owns its sockets.
  test('a waiting drop finishes old teardown before a later queued trial starts', () async {
    final old = _SlowProcess();
    nextProcess = () => processes.isEmpty ? old : _Process();
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final first = tunnels.holdForTrial(host);
    await entered.future;
    var dropped = false;
    final dropping = tunnels.dropFor(host).then((_) => dropped = true);
    final releasing = first.release();
    final second = tunnels.holdForTrial(host);
    addTearDown(() async {
      old.end('');
      await releasing;
      await second.release();
      await dropping;
    });
    checkControl = null;
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await first.ready, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(old.killed, isTrue, reason: 'a later trial cannot postpone the old master drop');
    expect(dropped, isFalse, reason: 'the drop must await the old process exit');
    expect(launches, hasLength(1), reason: 'the later trial waits for old teardown');
    old.end('');
    await dropping;
    await releasing;
    expect(await second.ready, isTrue);
    expect(launches, hasLength(2));
    expect(processes.last.killed, isFalse);
    await second.release();
  });

  // Prevents list replacement from stealing ports between registration and opening a card.
  test('replacement keeps a registered owner before its first raise', () async {
    await Future<void>.sync(() => tunnels.registerCards([host]));
    await Future<void>.sync(() => tunnels.replaceCards([]));
    final beta = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'beta'}),
      socketPath: '${folder.path}/b',
    );
    expect(
      () => tunnels.registerCards([beta]),
      throwsA(isA<HostFilesRefused>()),
      reason: 'registration owns the ports until its explicit drop',
    );
    await tunnels.dropFor(host);
    expect(() => tunnels.registerCards([beta]), returnsNormally);
    expect(launches, isEmpty);
  });

  // Prevents a queued replacement from omitting a newly listed card's fixed ports.
  test('a queued replacement reads the current card list when its step starts', () async {
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final raising = tunnels.raiseFor(host);
    await entered.future;
    final listed = <Machine>[host];
    final replacing = Future<void>.sync(() => tunnels.replaceCards(listed));
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
    );
    listed.add(beta);
    checkControl = null;
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await raising, isTrue);
    await replacing;
    final gamma = Machine.fromHostCard(
      HostCardSsh.fromStored({...beta.hostCard!.stored, 'name': 'gamma'}),
      socketPath: '${folder.path}/g',
    );
    expect(() => tunnels.registerCards([gamma]), throwsA(isA<HostFilesRefused>()));
    expect(launches, hasLength(1), reason: 'reserving a listed card must not start its SSH master');
  });

  // Prevents a late-listed host's preceding teardown from erasing its new reservation.
  test('a queued replacement waits for teardown on a host added to its input later', () async {
    final oldBeta = _SlowProcess();
    nextProcess = () => processes.isEmpty ? _Process() : oldBeta;
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    final raising = tunnels.raiseFor(host);
    await entered.future;
    final listed = <Machine>[host];
    var replaced = false;
    final replacing = Future<void>.sync(() => tunnels.replaceCards(listed)).then((_) => replaced = true);
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
    checkControl = null;
    expect(await tunnels.raiseFor(beta), isTrue);
    final dropping = tunnels.dropFor(beta);
    addTearDown(() async {
      oldBeta.end('');
      await dropping;
      await replacing;
    });
    await oldBeta.stopping.future;
    listed.add(beta);
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await raising, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(replaced, isFalse, reason: 'replacement must acquire the late-listed host queue before reserving it');
    oldBeta.end('');
    await dropping;
    await replacing;
    final gamma = Machine.fromHostCard(
      HostCardSsh.fromStored({...beta.hostCard!.stored, 'name': 'gamma'}),
      socketPath: '${folder.path}/g',
    );
    expect(() => tunnels.registerCards([gamma]), throwsA(isA<HostFilesRefused>()));
    expect(launches, hasLength(2), reason: 'replacement reserves beta without raising it again');
  });

  // Prevents cancellation before a first raise from leaking an imported port reservation.
  test('dropping a canceled queued first raise releases its registered card', () async {
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
    final entered = Completer<void>();
    final checked = Completer<ProcessResult>();
    checkControl = () {
      entered.complete();
      return checked.future;
    };
    await Future<void>.sync(() => tunnels.registerCards([host]));
    final raisingBeta = tunnels.raiseFor(beta);
    await entered.future;
    final barrier = Future<void>.sync(() => tunnels.registerCards([host, beta]));
    final raising = tunnels.raiseFor(host);
    final dropping = tunnels.dropFor(host);
    checkControl = null;
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await raisingBeta, isTrue);
    await barrier;
    expect(await raising, isFalse);
    await dropping;
    final gamma = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'name': 'gamma'}),
      socketPath: '${folder.path}/g',
    );
    expect(() => tunnels.registerCards([gamma]), returnsNormally);
    expect(launches, hasLength(1), reason: 'the canceled first raise must never launch');
    expect(processes.single.killed, isFalse, reason: 'the unrelated master must survive');
  });

  // Prevents a delayed replacement from restoring cards whose watchers were removed.
  for (final replace in [false, true]) {
    test('a concurrent ${replace ? 'replacement' : 'removal'} cannot restore a stale card', () async {
      final old = _SlowProcess();
      nextProcess = () => processes.isEmpty ? old : _Process();
      final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels, reach: (_) => _StoppedBackend());
      addTearDown(machines.dispose);
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
      await machines.add(host);
      await machines.of(host).untilAsked();
      await machines.add(beta);
      await machines.of(beta).untilAsked();
      final changed = Machine.fromHostCard(
        HostCardSsh.fromStored({...host.hostCard!.stored, 'services': _moved}),
        socketPath: '${folder.path}/changed',
        sshConfig: host.sshConfig,
      );
      final changedBeta = Machine.fromHostCard(
        HostCardSsh.fromStored({
          ...beta.hostCard!.stored,
          'services': {
            'forge': {'web_port': 20080, 'git_port': 20081},
            'matrix': {'port': 20082},
          },
        }),
        socketPath: '${folder.path}/changed-b',
        sshConfig: beta.sshConfig,
      );
      final replacing = machines.add(changed);
      addTearDown(() async {
        old.end('');
        await replacing;
      });
      await old.stopping.future;
      final changingBeta = replace ? machines.add(changedBeta) : machines.forget(beta);
      await Future<void>.delayed(Duration.zero);
      expect(machines.all, contains(beta), reason: 'list edits wait for the preceding replacement');
      old.end('');
      await replacing;
      await changingBeta;
      await tunnels.dropFor(beta);
      expect(machines.all, isNot(contains(beta)));
      expect(machines.all, contains(changed));
      if (replace) expect(machines.all, contains(changedBeta));
      final gamma = Machine.fromHostCard(
        HostCardSsh.fromStored({...beta.hostCard!.stored, 'name': 'gamma'}),
        socketPath: '${folder.path}/g',
      );
      expect(() => tunnels.registerCards([gamma]), returnsNormally, reason: 'the old beta ports must stay free');
    });
  }

  // Prevents a candidate probe from closing a master promoted to a watched connection.
  test('a watcher queued after trial release raises its own retained connection', () async {
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
    checkControl = null;
    checked.complete(ProcessResult(0, 0, '', ''));
    expect(await watching, isTrue);
    await releasing;
    expect(processes, hasLength(2));
    expect(processes.first.killed, isTrue, reason: 'release sees no watcher at the start of its step');
    expect(processes.last.killed, isFalse, reason: 'the new watcher still needs its master');
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
      HostCardSsh.fromStored({...host.hostCard!.stored, 'services': _moved}),
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
  test('canceling a queued trial leaves its preceding master stopped', () async {
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
    expect(processes.first.killed, isTrue, reason: 'release must finish before later queued consumers run');
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
      HostCardSsh.fromStored({...host.hostCard!.stored, 'services': _moved}),
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
      HostCardSsh.fromStored({...changed.hostCard!.stored, 'name': 'beta'}),
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

  test('replacing a card drops its old master and accepts its changed local ports', () async {
    final machines = Machines(Settings(MemorySettingsStore()), tunnels: tunnels, reach: (_) => _StoppedBackend());
    addTearDown(machines.dispose);
    await machines.add(host);
    await machines.of(host).untilAsked();
    final old = processes.single;
    final changed = Machine.fromHostCard(
      HostCardSsh.fromStored({...host.hostCard!.stored, 'services': _moved}),
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
    final unlockable = _onPort22(host);
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
    final raising = owned.raiseFor(unlockable);
    await entered.future;
    final dropping = owned.dropEverything();
    await Future<void>.delayed(Duration.zero);
    final canceledBeforeSettling = coreProcess.killed;
    coreProcess.end('');
    await raising;
    await dropping;
    expect(canceledBeforeSettling, isTrue, reason: 'shutdown must interrupt Core without waiting for its deadline');
    expect(master.killed, isTrue);
    expect(owned.manages(unlockable), isFalse);
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

  // Harm: a browser resolving <host>.localhost to ::1 first reaches another program listening there, not the card.
  test('publishes a pinned public identity and launches all fixed forwards on one owned master', () async {
    final before = HostCardSsh.ipv6Loopback;
    addTearDown(() => HostCardSsh.ipv6Loopback = before);
    HostCardSsh.ipv6Loopback = true;
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
    // Harm: a port ssh binds on the loopback is reached by every local account, each one the person on the forge.
    final private = File(host.sshConfig).absolute.parent.path;
    expect(forwards, [
      matches(RegExp('^${RegExp.escape(private)}/[^/:]+:/run/porelo-forge/web.sock\$')),
      matches(RegExp('^${RegExp.escape(private)}/[^/:]+:/run/porelo-forge/git.sock\$')),
      matches(RegExp('^${RegExp.escape(private)}/[^/:]+:/run/porelo-matrix/client.sock\$')),
      '${host.socketPath}:/run/porelo-host/people/alice/porelod.sock',
    ]);
    expect(command.where((word) => word == '-R'), hasLength(1));
    expect(command[command.indexOf('-R') + 1], '${host.hostCard!.returnSocket}:${folder.path}/m');
    expect(command, isNot(contains('-A')));
    expect(unlock.calls, [('alpha', host.sshConfig)]);
    expect(host.stored, isNot(contains('identity')));
    expect(host.hostCard!.forgeUrl, 'http://alpha.localhost:18080/');
    expect(host.hostCard!.matrixUrl, 'http://alpha.localhost:18082/');
  });

  // Harm: without ::1 an address by name may reach a port the window does not hold.
  test('without an IPv6 loopback the addresses name 127.0.0.1', () async {
    final before = HostCardSsh.ipv6Loopback;
    addTearDown(() => HostCardSsh.ipv6Loopback = before);
    HostCardSsh.ipv6Loopback = false;
    expect(await tunnels.raiseFor(host), isTrue);
    expect(launches.single, contains('ExitOnForwardFailure=yes'));
    expect(host.hostCard!.forgeUrl, 'http://127.0.0.1:18080/');
    expect(host.hostCard!.matrixUrl, 'http://127.0.0.1:18082/');
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

  // Harm: an automatic retry hides the refusal while the person is deciding how to answer it.
  // Harm: only ssh's last line is kept, so a real fault followed by its closing reads as "wait a minute".
  test('a fault said before the connection closed is not lost', () async {
    nextProcess = () => _Process()
      ..end(
        'Received disconnect from 203.0.113.9: Too many authentication failures\nConnection closed by 203.0.113.9 port 22\n',
      );
    checkControl = () async => ProcessResult(0, 1, '', '');
    expect(await tunnels.raiseFor(host), isFalse);
    expect(tunnels.of(host)?.problem, contains('Too many authentication failures'));
    expect(sshRefusalWords(tunnels.of(host)?.problem), isNot(contains('Wait a minute')));
  });

  // Harm: a noise line before it hides the closing, and the person is not told to wait.
  test('a warning before the closing does not change what it means', () async {
    nextProcess = () =>
        _Process()..end('Warning: Permanently added the host.\nConnection closed by 203.0.113.9 port 22\n');
    checkControl = () async => ProcessResult(0, 1, '', '');
    expect(await tunnels.raiseFor(host), isFalse);
    expect(sshRefusalWords(tunnels.of(host)?.problem), contains('Wait a minute'));
  });

  test('repeated SSH refusals keep the machine row steady during retries', () async {
    String row() {
      final tunnel = tunnels.of(host)!;
      return machineRowWords(
        where: host.name,
        tunnelUp: tunnel.state == TunnelState.up,
        tunnelWords: tunnel.words,
        tunnelProblem: tunnel.problem,
        fleet: 'not connected yet',
      );
    }

    final duringAttempts = <String>[];
    nextProcess = () {
      duringAttempts.add(row());
      return _Process()..end('Permission denied (publickey).');
    };
    checkControl = () async => ProcessResult(0, 1, '', '');

    expect(await tunnels.raiseFor(host), isFalse);
    expect(tunnels.of(host)!.problem, isNotEmpty);
    final refusedRow = row();
    for (var retry = 0; retry < 2; retry++) {
      await tunnels.raiseAgainIfItDropped(host);
      expect(row(), refusedRow, reason: 'another refusal leaves the same answer');
    }

    expect(launches, hasLength(3), reason: 'keeping the refusal must not stop automatic retries');
    expect(duringAttempts.skip(1), everyElement(refusedRow), reason: 'a retry must not hide the refusal');
  });

  // Prevents vault refusal from relabeling an SSH-reached host as unavailable.
  test('Core vault refusal remains separate from successful transport', () async {
    unlock.result = const HostUnlockResult(HostUnlockState.refused, 'The host vault refused unlock.');
    expect(await tunnels.raiseFor(host), isTrue);
    expect(tunnels.of(host)!.vaultProblem, 'The host vault refused unlock.');
    expect(tunnels.of(host)!.problem, isNull);
  });

  // Harm: the host vault is not unlocked from here, at another port or address or for another key, and nothing the
  // person sees says so: the machine reads as reached while every project on it waits.
  test('a vault the tunnel could not unlock is said where the machine\'s tunnel is shown', () async {
    unlock.result = const HostUnlockResult(HostUnlockState.refused, 'The host vault is not opened from here.');
    expect(await tunnels.raiseFor(host), isTrue);
    expect(tunnels.of(host)!.state, TunnelState.up);
    expect(tunnels.of(host)!.words, 'The host vault is not opened from here.');
    unlock.result = const HostUnlockResult(HostUnlockState.unlocked);
    await tunnels.of(host)!.unlockVault();
    expect(tunnels.of(host)!.words, isNull);
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
    final unlockable = _onPort22(host);
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
      unlockable,
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
    final unlockable = _onPort22(host);
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
    final result = await core.unlock(unlockable.hostCard!, '${folder.path}/alpha.conf');
    expect(commands, isEmpty);
    expect(result.state, HostUnlockState.refused);
  });

  // Harm: the vault share is sent to whatever the card's bare name resolves to on port 22, never the host Core
  // verified, or Core picks another of the agent's keys.
  for (final (name, change) in <(String, Map<String, Object?>)>[
    ('another SSH port', {'ssh_port': 2222}),
    ('an IPv6 address', {'ssh_port': 22, 'address': '2001:db8::7'}),
  ]) {
    test('a card on $name is not unlocked at another place, and says why', () async {
      final commands = <List<String>>[];
      final core = CoreHostUnlocker(
        environment: {'XDG_CONFIG_HOME': folder.path},
        start: (command) async {
          commands.add(command);
          return _Answered(0, '{"vault":"open"}');
        },
      );
      final card = HostCardSsh.fromStored({...host.hostCard!.stored, ...change});
      final result = await core.unlock(card, host.sshConfig);
      expect(commands, isEmpty);
      expect(result.state, HostUnlockState.refused);
      expect(result.words, contains('not opened from here'));
    });
  }

  test('Core unlock uses the agreed command and terminates its child on deadline', () async {
    final unlockable = _onPort22(host);
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
    final result = await core.unlock(unlockable.hostCard!, unlockable.sshConfig);
    expect(commands, [
      [
        'porelo',
        'host',
        'unlock',
        'alpha.example.org',
        '--host-key',
        hostKeyFingerprint,
        '--login',
        'alice',
        '--key',
        hostKeyFingerprint,
        '--json',
      ],
    ]);
    expect(process.killed, isTrue);
    expect(result.state, HostUnlockState.refused);
    expect(result.words, 'Core machine unlock timed out.');
  });

  for (final (code, answer, state) in const [
    (0, '{"vault":"open"}', HostUnlockState.unlocked),
    (77, '{"vault":"other-key"}', HostUnlockState.otherKey),
    (0, '{"vault":"other-key"}', HostUnlockState.refused),
    (77, '{"vault":"open"}', HostUnlockState.refused),
  ]) {
    // Prevents a vault opened by another key from being shown open or reset without the person's yes.
    test('Core unlock answers $state for exit $code with $answer and never says yes', () async {
      final unlockable = _onPort22(host);
      final commands = <List<String>>[];
      final core = CoreHostUnlocker(
        environment: {'XDG_CONFIG_HOME': folder.path},
        start: (command) async {
          commands.add(command);
          return _Answered(code, answer);
        },
      );
      final result = await core.unlock(unlockable.hostCard!, unlockable.sshConfig);
      expect(result.state, state);
      expect(commands.single, isNot(contains('--yes')));
      if (state == HostUnlockState.otherKey) expect(result.words, contains('kept'));
    });
  }

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

  /// Tunnels whose `ssh` is a real stand-in process that binds and listens on the daemon endpoint and the control
  /// socket, as a card's master does; each one started is added to [children].
  Tunnels masterStandIn(List<Process> children) {
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
        final child = await Process.start('python3', [
          '-c',
          'import socket,sys,time,os; os.umask(0o177); '
              'a=socket.socket(socket.AF_UNIX); a.bind(sys.argv[1]); a.listen(1); '
              'b=socket.socket(socket.AF_UNIX); b.bind(sys.argv[2]); b.listen(1); time.sleep(300)',
          daemon,
          control,
        ]);
        children.add(child);
        return child;
      },
      run: (_) async =>
          ProcessResult(0, FileSystemEntity.typeSync(control) == FileSystemEntityType.unixDomainSock ? 0 : 1, '', ''),
    );
    addTearDown(() async {
      await owned.dropEverything();
      owned.dispose();
    });
    return owned;
  }

  /// Tunnels whose `ssh` is a real stand-in process that listens on the daemon endpoint, the control socket and every
  /// socket a `-L` names here, echoing what comes on those last, as a card's master relays to the host's services.
  Tunnels relayingStandIn(Machine machine, List<Process> children) {
    final control = machine.hostCard!.controlSocket(machine.sshConfig);
    final owned = Tunnels(
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => true,
      portsAvailable: (_) async {},
      unlocker: unlock,
      start: (command) async {
        final forwarded = [
          for (var i = 0; i < command.length - 1; i++)
            if (command[i] == '-L' && command[i + 1].startsWith('/')) command[i + 1].split(':').first,
        ]..remove(machine.socketPath);
        final child = await Process.start('python3', [
          '-c',
          'import socket,sys,time,os,threading\n'
              'os.umask(0o177)\n'
              'def echo(c):\n'
              '  while True:\n'
              '    d=c.recv(4096)\n'
              '    if not d: break\n'
              '    c.sendall(d)\n'
              '  c.close()\n'
              'def serve(s):\n'
              '  while True:\n'
              '    c,_=s.accept(); threading.Thread(target=echo,args=(c,),daemon=True).start()\n'
              'def bound(p):\n'
              '  s=socket.socket(socket.AF_UNIX); s.bind(p); s.listen(8); return s\n'
              'keep=[bound(sys.argv[1]),bound(sys.argv[2])]\n'
              'for p in sys.argv[3:]: threading.Thread(target=serve,args=(bound(p),),daemon=True).start()\n'
              'time.sleep(300)\n',
          machine.socketPath,
          control,
          ...forwarded,
        ]);
        children.add(child);
        return child;
      },
      run: (_) async =>
          ProcessResult(0, FileSystemEntity.typeSync(control) == FileSystemEntityType.unixDomainSock ? 0 : 1, '', ''),
    );
    addTearDown(() async {
      await owned.dropEverything();
      owned.dispose();
    });
    return owned;
  }

  Future<int> freePort() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    return port;
  }

  Future<String> through(InternetAddress loopback, int port, String said) async {
    final connection = await Socket.connect(loopback, port, timeout: const Duration(seconds: 2));
    connection.write(said);
    await connection.flush();
    final heard = await connection.timeout(const Duration(seconds: 2)).first;
    connection.destroy();
    return utf8.decode(heard);
  }

  // Harm: a card's forge port ssh binds on the loopback is reached by every local account, each the person on the forge.
  test("the person's own connection to a card's ports reaches the host through the window, ssh binding none", () async {
    final bindBefore = PersonOnlyRelay.bindPort;
    addTearDown(() => PersonOnlyRelay.bindPort = bindBefore);
    PersonOnlyRelay.bindPort = PersonOnlyRelay.bindExclusive;
    final web = await freePort();
    final git = await freePort();
    final matrix = await freePort();
    final card = HostCardSsh.fromStored({
      ...host.hostCard!.stored,
      'services': {
        'forge': {'web_port': web, 'git_port': git},
        'matrix': {'port': matrix},
      },
    });
    final relayed = Machine.fromHostCard(card, socketPath: host.socketPath, sshConfig: host.sshConfig);
    final children = <Process>[];
    final owned = relayingStandIn(relayed, children);

    expect(await owned.raiseFor(relayed), isTrue, reason: owned.of(relayed)?.problem);

    for (final port in [web, git, matrix]) {
      expect(await through(InternetAddress.loopbackIPv4, port, 'to $port'), 'to $port');
      if (HostCardSsh.ipv6Loopback) {
        expect(await through(InternetAddress.loopbackIPv6, port, 'six $port'), 'six $port');
      }
    }
    await owned.dropEverything();
    await children.single.exitCode.timeout(const Duration(seconds: 1));
    await expectLater(Socket.connect(InternetAddress.loopbackIPv4, web), throwsA(isA<SocketException>()));
  });

  // Harm: ports a dropped card's relay bound after the drop held against every program until the window closes.
  test("a card dropped while its ports are asked about holds none of them afterwards", () async {
    final bindBefore = PersonOnlyRelay.bindPort;
    addTearDown(() => PersonOnlyRelay.bindPort = bindBefore);
    PersonOnlyRelay.bindPort = PersonOnlyRelay.bindExclusive;
    final web = await freePort();
    final card = HostCardSsh.fromStored({
      ...host.hostCard!.stored,
      'services': {
        'forge': {'web_port': web, 'git_port': await freePort()},
        'matrix': null,
      },
    });
    final relayed = Machine.fromHostCard(card, socketPath: host.socketPath, sshConfig: host.sshConfig);
    final asked = Completer<void>();
    final answer = Completer<void>();
    final tunnel = Tunnel(
      relayed,
      configEnvironment: {'XDG_CONFIG_HOME': folder.path},
      keyAvailable: (_) async => false,
      portsAvailable: (_) async {
        asked.complete();
        await answer.future;
      },
      unlocker: unlock,
      start: (_) async => _Process(),
      run: (_) async => ProcessResult(0, 1, '', ''),
    );
    final raising = tunnel.raise();
    await asked.future;

    await tunnel.drop();
    answer.complete();
    await raising;

    final again = await ServerSocket.bind(InternetAddress.loopbackIPv4, web);
    await again.close();
  });

  // Prevents a real stand-in process and its owned Unix endpoints from surviving shutdown.
  test('shutdown removes both owned sockets and the SSH stand-in process', () async {
    final children = <Process>[];
    final control = host.hostCard!.controlSocket(host.sshConfig);
    final owned = masterStandIn(children);
    expect(await owned.raiseFor(host), isTrue);
    expect(FileSystemEntity.typeSync(host.socketPath), FileSystemEntityType.unixDomainSock);
    expect(FileStat.statSync(host.socketPath).mode & 0x1ff, 0x180);
    await owned.dropEverything();
    await children.single.exitCode.timeout(const Duration(seconds: 1));
    expect(FileSystemEntity.typeSync(host.socketPath), FileSystemEntityType.notFound);
    expect(FileSystemEntity.typeSync(control), FileSystemEntityType.notFound);
  });

  // Harm: another program's socket put at a card's endpoint after its master answered is deleted at shutdown.
  test('a card endpoint replaced after its master answered survives shutdown, and still answers', () async {
    final children = <Process>[];
    final owned = masterStandIn(children);
    expect(await owned.raiseFor(host), isTrue);

    await anotherProgramAt(host.socketPath);
    await owned.dropEverything();
    await children.single.exitCode.timeout(const Duration(seconds: 1));

    expect(await answersAt(host.socketPath), isTrue, reason: 'another program\'s socket was removed');
  });

  // Harm: a forward left by a master that never answered blocks every later raise once its control socket is gone.
  test('a forward endpoint left without its control socket is cleared, and the card raised', () async {
    final children = <Process>[];
    final owned = masterStandIn(children);
    leftBehindAt(host.socketPath);

    expect(await owned.raiseFor(host), isTrue, reason: owned.of(host)?.problem);
    expect(children, hasLength(1));
  });

  // Harm: endpoints made where others may put files, whose leftovers can later never be told from theirs.
  test('a card whose endpoint folder others may write is refused before anything is launched', () async {
    Process.runSync('chmod', <String>['770', folder.path]);

    expect(await tunnels.raiseFor(host), isFalse);

    expect(tunnels.of(host)!.problem, contains('not yours alone'));
    expect(launches, isEmpty);
  });
}

/// A card's local service ports moved, which leaves its published files as they were.
const _moved = {
  'forge': {'web_port': 18090, 'git_port': 18091},
  'matrix': {'port': 18092},
};

class _Unlock implements HostUnlocker {
  final calls = <(String, String)>[];
  HostUnlockResult result = const HostUnlockResult(HostUnlockState.unlocked);
  @override
  Future<HostUnlockResult> unlock(HostCardSsh card, String config) async {
    calls.add((card.name, config));
    return result;
  }

  @override
  Future<void> cancel(String host) async {}
}

class _Answered extends Fake implements Process {
  _Answered(this.code, this.answer);
  final int code;
  final String answer;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(answer));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode async => code;
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
  @override
  Future<TakenProject> takeProject(String project) async => const TakenProject();

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

/// [machine] with its card on SSH's port 22, which Core's host unlock reaches.
Machine _onPort22(Machine machine) => Machine.fromHostCard(
  HostCardSsh.fromStored({...machine.hostCard!.stored, 'ssh_port': 22}),
  socketPath: machine.socketPath,
  sshConfig: machine.sshConfig,
);
