import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A socket left by a process that ended: bound, never removed, held by nobody. Made by another process, because a
/// socket this test closed itself would be removed by `dart:io` on close.
void leftBehindAt(String socket) {
  final made = Process.runSync('python3', <String>[
    '-c',
    'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])',
    socket,
  ]);
  expect(made.exitCode, 0, reason: '${made.stderr}');
}

/// Another program's socket put at [socket], in a process of its own that stays until the test ends: bound beside it
/// and renamed into place, as a program replacing a name does, so whatever was there before is replaced at once.
/// Listening where [listens], else only bound.
Future<void> anotherProgramAt(String socket, {bool listens = true}) async {
  final program = await Process.start('python3', <String>[
    '-c',
    'import socket,sys,os,time\n'
        's=socket.socket(socket.AF_UNIX)\n'
        's.bind(sys.argv[1]+".new")\n'
        '${listens ? 's.listen(4)\n' : ''}'
        'os.rename(sys.argv[1]+".new",sys.argv[1])\n'
        'print("ready",flush=True)\n'
        '${listens ? 'while True:\n  c,_=s.accept()\n  c.close()\n' : 'time.sleep(300)\n'}',
    socket,
  ]);
  addTearDown(() => program.kill(ProcessSignal.sigkill));
  final ready = await program.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first
      .timeout(const Duration(seconds: 10));
  expect(ready, 'ready');
}

/// Whether something accepts a connection at [socket].
Future<bool> answersAt(String socket) async {
  try {
    (await Socket.connect(InternetAddress(socket, type: InternetAddressType.unix), 0)).destroy();
    return true;
  } on SocketException {
    return false;
  }
}
