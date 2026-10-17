// Linux only: it stands a daemon on a unix socket, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

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
          ...utf8.encode(jsonEncode(<String, Object?>{
            'parameters': <String, Object?>{'vendor': 'fuin.org', 'product': 'Porelo'},
          })),
          0,
        ]);
      });
    });
    addTearDown(() async {
      await daemon.close();
      place.deleteSync(recursive: true);
    });
  });

  const joins = 'import socket,sys,threading\n'
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
    final reply = await connection.call('org.varlink.service.GetInfo');

    expect(reply['product'], 'Porelo');
    connection.close();
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

    await expectLater(backend.open(), throwsA(isA<VarlinkDisconnected>().having((e) => e.message, 'message', 'Ubuntu is stopped.')));
    expect(asked, 1);
  });

  test('a relay that cannot be started is a lost connection, in words', () async {
    const backend = Backend(socketPath: '', label: 'missing', relay: <String>['a-program-that-is-not-there']);

    await expectLater(backend.open(), throwsA(isA<VarlinkDisconnected>()));
  });
}
