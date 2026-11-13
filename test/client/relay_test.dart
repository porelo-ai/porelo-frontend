// Linux only: it stands a daemon on a unix socket, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/loopback_carrier.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A daemon reached through a relay process, as a Porelo in WSL is reached from Windows through
/// `wsl.exe -d <distribution> -- porelo daemon connect`: the same Varlink over the relay's standard
/// input and output. Here the relay is a small program joining them to a unix socket, as
/// `porelo daemon connect` does, and the daemon one that answers `GetInfo`.
void main() {
  late Directory place;
  late ServerSocket daemon;
  late String socket;

  setUp(() async {
    place = Directory.systemTemp.createTempSync('porelo-relay-');
    socket = '${place.path}/porelod.sock';
    daemon = await ServerSocket.bind(InternetAddress(socket, type: InternetAddressType.unix), 0);
    daemon.listen((client) {
      client.listen((bytes) {
        if (!bytes.contains(0)) return;
        client.add(<int>[
          ...utf8.encode(
            jsonEncode(<String, Object?>{
              'parameters': <String, Object?>{'vendor': 'fuin.org', 'product': 'Porelo'},
            }),
          ),
          0,
        ]);
      });
    });
    addTearDown(() async {
      await daemon.close();
      place.deleteSync(recursive: true);
    });
  });

  const joins =
      'import socket,sys,threading\n'
      's=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])\n'
      'def back():\n'
      '  while True:\n'
      '    b=s.recv(65536)\n'
      '    if not b: break\n'
      '    sys.stdout.buffer.write(b); sys.stdout.buffer.flush()\n'
      'threading.Thread(target=back,daemon=True).start()\n'
      'while True:\n'
      '  b=sys.stdin.buffer.read1(65536)\n'
      '  if not b: break\n'
      '  s.sendall(b)\n';

  test('a call through the relay is answered, with no socket opened by the interface', () async {
    final backend = Backend(socketPath: '', label: 'relayed', relay: <String>['python3', '-c', joins, socket]);

    final connection = await backend.open();
    // Closing is what ends the relay's process, so it is closed after a red expect too.
    addTearDown(connection.close);
    final reply = await connection.call('org.varlink.service.GetInfo');

    expect(reply['product'], 'Porelo');
  });

  test('ssh preserves framed requests through a plain socket path', () async {
    final mock = MockDaemon();
    await mock.start();
    addTearDown(mock.stop);
    mock.method('Echo', (parameters) => parameters);
    const remote = '/run/user/1000/porelo/porelod.sock';
    final script = File('${place.path}/ssh');
    script.writeAsStringSync(
      'import shlex,sys\n'
      'real=sys.argv[1]\n'
      'args=sys.argv[2:]\n'
      'assert args[:10] == ["-T", "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15", "-o", "ControlMaster=no", "-o", "ControlPath=none", "--"]\n'
      'assert args[10] == "user@box"\n'
      'login=shlex.split(args[11])\n'
      'command=shlex.split(login[-1])\n'
      'assert command[:4] == ["porelo", "daemon", "connect", "--socket"]\n'
      'assert command[4] == "$remote"\n'
      'sys.argv=[sys.argv[0], real]\n'
      '$joins',
    );
    final machine = Machine(name: 'box', socketPath: '', host: 'user@box', remoteSocket: remote);
    final relay = machine.relayOn(windows: true, environment: const <String, String>{})!;
    final backend = Backend(
      socketPath: '',
      label: 'ssh',
      relay: <String>['python3', script.path, mock.socketPath, ...relay.command.skip(1)],
    );
    final connection = await backend.open();
    addTearDown(connection.close);
    final payload = <String, dynamic>{'text': 'before\u0000after — quoted socket'};
    expect(await connection.call('org.fuin.porelo.Tasks1.Echo', payload), payload);
  });

  test('an ssh authentication refusal ends promptly with its diagnostic instead of waiting for input', () async {
    final script = File('${place.path}/ssh-refused');
    script.writeAsStringSync('import sys\nsys.stderr.write("Permission denied (publickey)\\n")\nsys.exit(255)\n');
    final backend = Backend(socketPath: '', label: 'refused', relay: <String>['python3', script.path]);
    final connection = await backend.open();
    addTearDown(connection.close);
    await expectLater(
      connection.call('org.varlink.service.GetInfo').timeout(const Duration(seconds: 2)),
      throwsA(isA<VarlinkDisconnected>().having((e) => e.message, 'ssh refusal', contains('publickey'))),
    );
  });

  // Preserves the actionable transport refusal instead of offering to start a daemon.
  test('an ssh trial explains authentication failures using the login configuration', () async {
    final previous = desk;
    desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
    addTearDown(() => desk = previous);
    const machine = Machine(
      name: 'box',
      socketPath: '',
      host: 'user@box',
      remoteSocket: '/run/user/1000/porelo/porelod.sock',
    );
    final ran = <List<String>>[];
    final tunnels = Tunnels(
      start: (_) async => fail('A relay must not raise a forward.'),
      run: (command) async {
        ran.add(command);
        return ProcessResult(0, 0, 'identityfile ~/.ssh/work\n', '');
      },
    );
    addTearDown(tunnels.dispose);
    final trial = await tryAMachine(
      machine,
      tunnels: tunnels,
      reach: (_) => PoreloBackend(
        Backend(
          socketPath: '',
          label: 'refused',
          relay: <String>[
            'python3',
            '-c',
            'import sys\nsys.stderr.write("Permission denied (publickey)")\nsys.exit(255)',
          ],
        ),
      ),
    );
    expect(trial.reached, isFalse);
    expect(trial.nothingServing, isFalse);
    expect(trial.words, contains('accepted none of the keys'));
    expect(trial.words, contains('~/.ssh/work'));
    expect(ran.single.first, r'D:\Windows\System32\OpenSSH\ssh.exe');
  });

  // Offers a start only for the account that can actually serve the requested socket.
  for (final uid in <int>[1000, 1001]) {
    test('a relay remote failure checks login uid $uid before offering a start', () async {
      final previous = desk;
      desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
      addTearDown(() => desk = previous);
      const machine = Machine(
        name: 'box',
        socketPath: '',
        host: 'user@box',
        remoteSocket: '/run/user/1000/porelo/porelod.sock',
      );
      final tunnels = Tunnels(
        start: (_) async => fail('No forward may start.'),
        run: (command) async {
          expect(command.first, r'D:\Windows\System32\OpenSSH\ssh.exe');
          expect(command.last, 'id -u');
          return ProcessResult(0, 0, '$uid\n', '');
        },
      );
      addTearDown(tunnels.dispose);
      final trial = await tryAMachine(
        machine,
        tunnels: tunnels,
        reach: (_) => PoreloBackend(
          Backend(
            socketPath: '',
            label: 'missing daemon',
            relay: <String>['python3', '-c', 'import sys\nsys.stderr.write("connect: no socket")\nsys.exit(1)'],
          ),
        ),
      );
      expect(trial.nothingServing, uid == 1000);
      expect(trial.words, contains(uid == 1000 ? 'nothing answers at ${machine.remoteSocket}' : 'another user'));
    });
  }

  test('a relay keeps only the last 8192 bytes of a long diagnostic without a newline', () async {
    final backend = Backend(
      socketPath: '',
      label: 'noisy',
      relay: <String>['python3', '-c', 'import sys\nsys.stderr.write("a" * 99996 + "TAIL")\nsys.exit(255)'],
    );
    final connection = await backend.open();
    addTearDown(connection.close);
    await expectLater(
      connection.call('org.varlink.service.GetInfo'),
      throwsA(isA<VarlinkDisconnected>().having((error) => error.message, 'bounded diagnostic', '${'a' * 8188}TAIL')),
    );
  });

  test('an immediate relay exit that closes stdin preserves ssh words in the trial', () async {
    final previous = desk;
    desk = Desk.of('windows', const <String, String>{});
    addTearDown(() => desk = previous);
    const machine = Machine(name: 'box', socketPath: '', host: 'box', remoteSocket: '/s');
    final tunnels = Tunnels(run: (_) async => ProcessResult(0, 0, '', ''));
    addTearDown(tunnels.dispose);
    final trial = await tryAMachine(
      machine,
      tunnels: tunnels,
      reach: (_) => PoreloBackend(
        Backend(
          socketPath: '',
          label: 'closed input',
          relay: <String>[
            'python3',
            '-c',
            'import os,sys\nos.close(0)\nsys.stderr.write("ssh: custom refusal")\nsys.exit(255)',
          ],
        ),
      ),
    );
    expect(trial.words, 'ssh: custom refusal');
  });

  // A failed write must not replace the transport's actionable diagnostic with EPIPE.
  test('a closed relay input keeps its diagnostic when a request fills the pipe', () async {
    final backend = Backend(
      socketPath: '',
      label: 'closed input',
      relay: <String>[
        'python3',
        '-c',
        'import os,sys\nos.close(0)\nsys.stderr.write("ssh: custom refusal")\nsys.exit(255)',
      ],
    );
    final connection = await backend.open();
    addTearDown(connection.close);
    await expectLater(
      connection.call('Echo', <String, dynamic>{'large': 'x' * 1000000}),
      throwsA(
        isA<VarlinkDisconnected>().having((error) => error.message, 'transport diagnostic', 'ssh: custom refusal'),
      ),
    );
  });

  test('a relay that may not run now is not started, and why is said', () async {
    var asked = 0;
    final backend = Backend(
      socketPath: '',
      label: 'stopped',
      relay: const <String>['a-program-that-is-not-there'],
      whyNotNow: () async {
        asked++;
        return 'Ubuntu is stopped.';
      },
    );

    await expectLater(
      backend.open(),
      throwsA(isA<VarlinkDisconnected>().having((e) => e.message, 'message', 'Ubuntu is stopped.')),
    );
    expect(asked, 1);
  });

  test('a relay that cannot be started is a lost connection, in words', () async {
    const backend = Backend(socketPath: '', label: 'missing', relay: <String>['a-program-that-is-not-there']);

    await expectLater(backend.open(), throwsA(isA<VarlinkDisconnected>()));
  });

  group("on Windows a machine's daemon relays wait for places of their own", () {
    const remote = '/run/user/1000/porelo/porelod.sock';
    const machine = Machine(name: 'box', socketPath: '', host: 'user@box', remoteSocket: remote);
    late MockDaemon mock;
    late int started;
    late int live;
    late int most;

    setUp(() async {
      mock = MockDaemon();
      await mock.start();
      addTearDown(mock.stop);
      started = 0;
      live = 0;
      most = 0;
    });

    /// Stands in for ssh with a relay to the mock, counting the relays started and those still running.
    Future<Process> relayWith(String program) async {
      final process = await Process.start('python3', <String>['-c', program, mock.socketPath]);
      started++;
      live++;
      if (live > most) most = live;
      unawaited(process.exitCode.then((_) => live--));
      return process;
    }

    Future<Process> relay(String executable, List<String> arguments) => relayWith(joins);

    Future<void> until(bool Function() holds, String what) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!holds()) {
        if (DateTime.now().isAfter(deadline)) fail('waited ten seconds for $what');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    test('a flood of calls beside a watch starts no relay past the places, and every call is answered', () async {
      final gate = Completer<void>();
      final arrived = <Object?>[];
      mock.method('Stop', (parameters) async {
        arrived.add(parameters['task']);
        await gate.future;
        return <String, dynamic>{'outcome': 'STOPPED'};
      });
      final events = StreamController<Map<String, dynamic>>();
      addTearDown(events.close);
      mock.pushes('Watch', (_) => events.stream);
      final backend = Machines.backendOn(
        machine,
        windows: true,
        environment: const <String, String>{},
        budget: CarrierBudget(daemonCalls: 2),
        startRelay: relay,
      );
      final client = await PoreloClient.connect(backend);
      final seen = <List<Task>>[];
      final watching = client.watchTasks().listen(seen.add);
      addTearDown(watching.cancel);

      final stops = [for (var i = 0; i < 6; i++) client.stop('t$i')];
      await until(() => arrived.length >= 2, 'two calls to arrive');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(arrived, hasLength(2), reason: 'two places for calls, so the other four wait without a relay');
      expect(live, 3, reason: 'the watch and the two calls each hold a relay, and nothing else runs');

      gate.complete();
      final answered = await Future.wait(stops).timeout(const Duration(seconds: 20));
      expect([for (final each in answered) each.outcome.name], everyElement('STOPPED'), reason: 'none is refused');
      expect(started, 8, reason: 'one relay for the connect, one for the watch and one for each call');
      expect(most, lessThanOrEqualTo(3), reason: 'never more relays at once than the watch and the two places');

      events.add(<String, dynamic>{'tasks': <Object?>[]});
      await until(() => seen.isNotEmpty, 'the watch to answer');
    });

    test(
      'with a small cap of all, a flood of calls and of carried connections stays within it beside a watch',
      () async {
        final budget = CarrierBudget(inAll: 5, daemonCalls: 2, startsPerSecond: 1000);
        var carried = 0;
        var most = 0;
        void count(int by) {
          carried += by;
          // The watch's relay is outside the cap of all; everything else counts.
          if (carried + live - 1 > most) most = carried + live - 1;
        }

        final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = probe.port;
        await probe.close();
        final carrier = LoopbackCarrier(
          {port: CarriedRole.forgeWeb},
          budget: budget,
          carry: (role) async {
            // A service that never answers holds its place until its connection ends.
            final process = await Process.start('python3', <String>['-c', 'import sys\nsys.stdin.buffer.read()']);
            count(1);
            unawaited(process.exitCode.then((_) => count(-1)));
            return process;
          },
        );
        addTearDown(carrier.release);
        await carrier.hold();
        carrier.carrying = true;
        final gate = Completer<void>();
        mock.method('Stop', (parameters) async {
          await gate.future;
          return <String, dynamic>{'outcome': 'STOPPED'};
        });
        final events = StreamController<Map<String, dynamic>>();
        addTearDown(events.close);
        mock.pushes('Watch', (_) => events.stream);
        final backend = Machines.backendOn(
          machine,
          windows: true,
          environment: const <String, String>{},
          budget: budget,
          startRelay: (executable, arguments) async {
            final process = await relay(executable, arguments);
            count(0);
            return process;
          },
        );
        final client = await PoreloClient.connect(backend);
        final seen = <List<Task>>[];
        final watching = client.watchTasks().listen(seen.add);
        addTearDown(watching.cancel);
        await until(() => live == 1 && mock.openConnections == 1, 'the watch alone to hold a relay');

        final clients = [for (var i = 0; i < 8; i++) await Socket.connect(InternetAddress.loopbackIPv4, port)];
        for (final each in clients) {
          addTearDown(each.destroy);
        }
        await until(() => carrier.connections == 5 && carried == 5, 'the carried connections to fill the cap of all');
        final stops = [for (var i = 0; i < 3; i++) client.stop('t$i')];
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(live, 1, reason: 'five carried connections hold the cap of all beside the watch, and the calls wait');

        for (final each in clients) {
          each.destroy();
        }
        gate.complete();
        final answered = await Future.wait(stops).timeout(const Duration(seconds: 20));
        expect([for (final each in answered) each.outcome.name], everyElement('STOPPED'), reason: 'every call answers');
        events.add(<String, dynamic>{'tasks': <Object?>[]});
        await until(() => seen.isNotEmpty, 'the watch to answer');
        expect(most, lessThanOrEqualTo(5), reason: 'no ssh child but the watch ever ran past the cap of all');
      },
    );

    Backend windowsBackend(CarrierBudget budget) => Machines.backendOn(
      machine,
      windows: true,
      environment: const <String, String>{},
      budget: budget,
      startRelay: relay,
    );

    /// Has [method] stream without end, noting each call as it reaches the daemon.
    void endless(String method, List<String> arrived) => mock.pushes(method, (parameters) {
      arrived.add(method);
      return StreamController<Map<String, dynamic>>().stream;
    });

    test('every watch the window holds runs beside a full pool of calls', () async {
      final gate = Completer<void>();
      final arrived = <String>[];
      mock.method('Stop', (parameters) async {
        arrived.add('Stop');
        await gate.future;
        return <String, dynamic>{'outcome': 'STOPPED'};
      });
      for (final method in ['Watch', 'Prompts', 'Talk', 'Authorizations']) {
        endless(method, arrived);
      }
      final client = await PoreloClient.connect(windowsBackend(CarrierBudget(daemonCalls: 2)));
      final stops = [for (var i = 0; i < 3; i++) client.stop('t$i')];
      await until(() => arrived.where((each) => each == 'Stop').length == 2, 'the pool to fill with calls');
      final watching = [
        client.watchTasks().listen((_) {}),
        client.prompts().listen((_) {}),
        client.talk().listen((_) {}),
        client.authorizations().listen((_) {}),
      ];
      for (final each in watching) {
        addTearDown(each.cancel);
      }
      await until(() => arrived.length == 6, 'every watch to reach the daemon');
      expect(arrived.toSet(), {'Stop', 'Watch', 'Prompts', 'Talk', 'Authorizations'});
      gate.complete();
      await Future.wait(stops).timeout(const Duration(seconds: 20));
    });

    test('pull request watches and log tails without end leave the pool to calls and streams that end', () async {
      final arrived = <String>[];
      endless('WatchPullRequests', arrived);
      endless('Tail', arrived);
      mock.method('AgentSignInWait', (parameters) async {
        arrived.add('AgentSignInWait');
        return <String, dynamic>{'signedIn': true};
      });
      mock.method('List', (parameters) => <String, dynamic>{'tasks': <Object?>[]});
      final client = await PoreloClient.connect(windowsBackend(CarrierBudget(daemonCalls: 2)));
      final following = [
        for (var i = 0; i < 3; i++) client.watchPullRequests('p$i').listen((_) {}),
        client.tailLog('t', 'task.log').listen((_) {}),
      ];
      for (final each in following) {
        addTearDown(each.cancel);
      }
      await until(() => arrived.length == 4, 'every pull request watch and the tail to reach the daemon');
      final waited = await client.agentSignInWait('claude').first.timeout(const Duration(seconds: 10));
      expect(waited, isNotNull, reason: 'a stream that ends still passes beside them');
      expect((await client.tasks().timeout(const Duration(seconds: 10))), isEmpty, reason: 'and so does a call');
    });

    test('a stream left at once starts no relay', () async {
      endless('Tail', <String>[]);
      final client = await PoreloClient.connect(windowsBackend(CarrierBudget(daemonCalls: 2)));
      await until(() => live == 0, 'the connect relay to exit');
      await client.tailLog('t', 'task.log').listen((_) {}).cancel();
      await client.agentSignInWait('claude').listen((_) {}).cancel();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(started, 1, reason: 'only the connect started a relay');
    });

    test('a stream left while it waits for a place starts no relay', () async {
      mock.pushes('Prepare', (_) => StreamController<Map<String, dynamic>>().stream);
      final client = await PoreloClient.connect(windowsBackend(CarrierBudget(daemonCalls: 2)));
      await until(() => live == 0, 'the connect relay to exit');
      final first = client.prepare('p').listen((_) {});
      await until(() => started == 2, 'the first stream to start its relay');
      final second = client.prepare('p').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(started, 2, reason: 'a stream may not take the place kept for calls');
      await second.cancel();
      await first.cancel();
      await until(() => live == 0, 'the first stream to exit');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(started, 2, reason: 'the stream that was left never starts a relay');
    });

    test('a place is free again once its relay could not start', () async {
      var refusals = 2;
      final backend = Machines.backendOn(
        machine,
        windows: true,
        environment: const <String, String>{},
        budget: CarrierBudget(daemonCalls: 2, inAll: 1),
        startRelay: (executable, arguments) async {
          if (refusals-- > 0) throw const ProcessException('ssh', <String>[], 'not there');
          return relay(executable, arguments);
        },
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(backend.open().timeout(const Duration(seconds: 5)), throwsA(isA<VarlinkDisconnected>()));
      }
      final connection = await backend.open().timeout(const Duration(seconds: 5));
      addTearDown(connection.close);
      expect((await connection.call('org.varlink.service.GetInfo'))['product'], isNotNull);
    });

    test('a relay that does not end when it is closed is ended by force, and its place is free again', () async {
      final backend = Machines.backendOn(
        machine,
        windows: true,
        environment: const <String, String>{},
        budget: CarrierBudget(daemonCalls: 2, inAll: 1),
        startRelay: (executable, arguments) =>
            relayWith('import signal\nsignal.signal(signal.SIGTERM, signal.SIG_IGN)\n$joins'),
      );
      final stubborn = await backend.open();
      await stubborn.call('org.varlink.service.GetInfo');
      await stubborn.close();
      final next = await backend.open().timeout(const Duration(seconds: 8));
      addTearDown(next.close);
      expect(started, 2);
    });

    test('on Linux a machine is reached over its socket as before, with no relay to admit', () async {
      final backend = Machines.backendOn(
        Machine(name: 'here', socketPath: mock.socketPath, host: 'user@box', remoteSocket: remote),
        windows: false,
        environment: const <String, String>{},
        budget: CarrierBudget(daemonCalls: 2, inAll: 1),
        startRelay: relay,
      );
      final connections = [for (var i = 0; i < 4; i++) await backend.open().timeout(const Duration(seconds: 5))];
      for (final each in connections) {
        addTearDown(each.close);
      }
      await until(() => mock.openConnections == 4, 'every connection to reach the daemon');
      expect(started, 0, reason: 'nothing is started on Linux');
    });
  });
}
