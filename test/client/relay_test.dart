// Linux only: it stands a daemon on a unix socket, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
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
}
