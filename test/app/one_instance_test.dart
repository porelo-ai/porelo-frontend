import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/one_instance.dart';

import '../support/other_sockets.dart';

/// Two interfaces running is not untidy, it is wrong: each watches every configured machine, so a
/// clearance question is raised twice and answered by whichever window somebody happened to see.
/// The tests at a unix socket are Linux's; the loopback way below is Windows', and runs on both.
void main() {
  late Directory runtime;
  late String path;

  setUp(() {
    // This account's alone, as the runtime directory is: the one place its socket is ever removed.
    runtime = Directory.systemTemp.createTempSync('one-');
    Process.runSync('chmod', <String>['700', runtime.path]);
    path = '${runtime.path}/porelo-frontend.sock';
    addTearDown(() => runtime.deleteSync(recursive: true));
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
    leftBehindAt(path);

    final taking = await OneInstance.take(comeForward: () {}, at: path);

    expect(taking.inCharge, isTrue, reason: taking.unsure);
    await taking.release();
  }, tags: 'linux');

  // Harm: a file of somebody's at the path is deleted, since a connect to a file is refused as to a dead socket.
  test('a file at the path is left alone, and the launch says why it stops', () async {
    File(path).writeAsStringSync('somebody else\'s');

    final taking = await OneInstance.take(comeForward: () {}, at: path);

    expect(taking.inCharge, isFalse);
    expect(taking.unsure, contains('no leftover'));
    expect(File(path).readAsStringSync(), 'somebody else\'s');
  }, tags: 'linux');

  // Harm: under too many open files the probe fails, and a running window's socket is deleted at start.
  test('a probe that fails for a reason of its own leaves the socket, and the launch says so', () async {
    await anotherProgramAt(path);

    final taking = await OneInstance.take(
      comeForward: () {},
      at: path,
      connect: (_) async => throw const SocketException('', osError: OSError('Too many open files', 24)),
    );

    expect(taking.inCharge, isFalse);
    expect(taking.unsure, contains('could not be told'));
    expect(await answersAt(path), isTrue, reason: 'the running window\'s socket was removed');
  }, tags: 'linux');

  // Harm: closing the listener removes whatever is at its path by then, another program's socket included.
  test('a socket put at the path while it runs survives the release', () async {
    final first = await OneInstance.take(comeForward: () {}, at: path);
    expect(first.inCharge, isTrue, reason: first.unsure);

    await anotherProgramAt(path);
    await first.release();

    expect(await answersAt(path), isTrue, reason: 'another program\'s socket was removed');
  }, tags: 'linux');

  // Harm: two launches at once both find the path free and both take charge.
  test('of two launches at once, one takes charge', () async {
    final both = await Future.wait([
      OneInstance.take(comeForward: () {}, at: path),
      OneInstance.take(comeForward: () {}, at: path),
    ]);

    expect(both.where((each) => each.inCharge), hasLength(1));
    for (final each in both) {
      await each.release();
    }
  }, tags: 'linux');

  // Harm: a socket made where others may put files, whose leftover can later never be told from theirs.
  test('a folder others may write is not used, and the launch says why it stops', () async {
    Process.runSync('chmod', <String>['770', runtime.path]);

    final taking = await OneInstance.take(comeForward: () {}, at: path);

    expect(taking.inCharge, isFalse);
    expect(taking.unsure, contains('not yours alone'));
    expect(runtime.listSync(), isEmpty);
  }, tags: 'linux');

  test('releasing leaves nothing behind for the next launch to trip over', () async {
    final first = await OneInstance.take(comeForward: () {}, at: path);

    await first.release();

    expect(runtime.listSync(), isEmpty, reason: 'neither the path nor the name it was bound at stays');
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
