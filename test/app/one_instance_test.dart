import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/one_instance.dart';

/// Two interfaces running is not untidy, it is wrong: each watches every configured machine, so a
/// clearance question is raised twice and answered by whichever window somebody happened to see.
/// The tests at a unix socket are Linux's; the loopback way below is Windows', and runs on both.
void main() {
  late String path;

  setUp(() {
    path = '/tmp/porelo-one-${DateTime.now().microsecondsSinceEpoch}.sock';
    addTearDown(() {
      final socket = File(path);
      if (socket.existsSync()) socket.deleteSync();
    });
  });

  test('the first launch takes charge', () async {
    final first = await OneInstance.take(comeForward: () {}, at: path);

    expect(first.inCharge, isTrue);
    await first.release();
  }, tags: 'linux');

  test('a second launch joins rather than competing, and asks for the window', () async {
    var asked = 0;
    final first = await OneInstance.take(comeForward: () => asked++, at: path);

    final second = await OneInstance.take(comeForward: () {}, at: path);

    expect(second.inCharge, isFalse, reason: 'two would raise everything twice');
    while (asked == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(asked, 1);
    await first.release();
  }, tags: 'linux');

  test('a socket left by a run that died is taken over, not surrendered to', () async {
    // Otherwise one crash means the interface can never be opened again without somebody knowing
    // to delete a file they have never heard of.
    File(path).writeAsStringSync('');

    final taking = await OneInstance.take(comeForward: () {}, at: path);

    expect(taking.inCharge, isTrue);
    await taking.release();
  }, tags: 'linux');

  test('releasing leaves nothing behind for the next launch to trip over', () async {
    final first = await OneInstance.take(comeForward: () {}, at: path);

    await first.release();

    expect(File(path).existsSync(), isFalse);
  }, tags: 'linux');

  group('over the loopback address, as on Windows', () {
    late String portFile;

    setUp(() {
      portFile = '${Directory.systemTemp.path}/porelo-one-${DateTime.now().microsecondsSinceEpoch}.port';
      addTearDown(() {
        final file = File(portFile);
        if (file.existsSync()) file.deleteSync();
      });
    });

    test('a second launch joins rather than competing, and asks for the window', () async {
      var asked = 0;
      final first = await OneInstance.take(comeForward: () => asked++, at: portFile, overLoopback: true);

      final second = await OneInstance.take(comeForward: () {}, at: portFile, overLoopback: true);

      expect(first.inCharge, isTrue);
      expect(second.inCharge, isFalse, reason: 'two would raise everything twice');
      while (asked == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await first.release();
      expect(File(portFile).existsSync(), isFalse, reason: 'the next launch must not trip over it');
    });

    test('a port some other program answers on after a crash is taken over, not surrendered to', () async {
      final other = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(other.close);
      other.listen((from) {
        from.write('SSH-2.0-somebody-else\n');
        from.destroy();
      });
      File(portFile).writeAsStringSync('${other.port}');

      final taking = await OneInstance.take(comeForward: () {}, at: portFile, overLoopback: true);

      expect(taking.inCharge, isTrue);
      await taking.release();
    });

    test('a port file that names nothing is taken over', () async {
      File(portFile).writeAsStringSync('not a port');

      final taking = await OneInstance.take(comeForward: () {}, at: portFile, overLoopback: true);

      expect(taking.inCharge, isTrue);
      await taking.release();
    });
  });
}
