// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/client.dart';
import 'package:sokar_frontend/src/app/fleet_backend.dart';
import 'package:sokar_frontend/src/app/hand_in.dart';
import 'package:sokar_frontend/src/mock/machine.dart';
import 'package:sokar_frontend/src/mock/mock_daemon.dart';

/// Holds handing a file to a running task to what the machine answers, over a real socket.
///
/// Each part is a call of its own, so these run the client against the stand-in machine rather
/// than in a widget test, whose clock cannot carry a socket.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;
  late _Counting backend;
  late Directory here;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, pace: Duration.zero);
    backend = _Counting(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
    here = await Directory.systemTemp.createTemp('hand-in-');
  });

  tearDown(() async {
    await machine.close();
    await daemon.stop();
    await here.delete(recursive: true);
  });

  Future<Task> aRunningTask() async =>
      (await backend.tasks()).firstWhere((each) => each.running);

  Future<File> aFile(String name, int bytes) async {
    final file = File('${here.path}/$name');
    await file.writeAsBytes(List<int>.generate(bytes, (i) => (i * 31 + 7) % 251));
    return file;
  }

  test('a small file is placed in one part and listed on the task', () async {
    final task = await aRunningTask();
    final file = await aFile('notes.txt', 300);
    final handing = HandingIn();

    final placed = await handing.give(backend, task, file.path);

    expect(placed, isNotNull, reason: handing.said);
    expect(placed!.bytes, 300);
    expect(placed.sha256, crypto.sha256.convert(await file.readAsBytes()).toString(),
        reason: 'the machine checked the hash the client sent');
    final listed = (await backend.tasks()).firstWhere((each) => each.name == task.name);
    expect(listed.files!.map((each) => each.name), ['notes.txt'],
        reason: 'the task lists the file once the machine placed it');
  });

  test('a file larger than one part goes in several and arrives whole', () async {
    final task = await aRunningTask();
    final size = HandingIn.partBytes * 3 + 1234;
    final file = await aFile('big.bin', size);

    final placed = await HandingIn().give(backend, task, file.path);

    expect(backend.parts, 4, reason: 'three whole parts and the rest');
    expect(placed?.bytes, size, reason: 'the parts added up to the whole file');
    expect(placed?.sha256, crypto.sha256.convert(await file.readAsBytes()).toString());
  });

  test('a transfer cut off midway goes on where the machine says, not from the start', () async {
    final task = await aRunningTask();
    final file = await aFile('cut.bin', HandingIn.partBytes * 2 + 10);
    final content = await file.readAsBytes();
    final sha256 = crypto.sha256.convert(content).toString();
    // An earlier attempt got one part through before its connection went.
    await backend.handIn(task.name,
        name: 'cut.bin',
        bytes: content.length,
        sha256: sha256,
        offset: 0,
        part: content.sublist(0, HandingIn.partBytes));

    final handing = HandingIn();
    backend.parts = 0;
    final placed = await handing.give(backend, task, file.path);

    expect(backend.parts, 3,
        reason: 'one refused at offset 0, then the two that were still missing');
    expect(placed?.sha256, sha256, reason: handing.said);
    expect(placed?.bytes, content.length,
        reason: 'resumed at the part the machine held, so nothing arrived twice');
  });

  test('a file larger than the task takes is refused before anything is sent', () async {
    machine.handInLimit = 100;
    final task = await aRunningTask();
    final file = await aFile('too-big.bin', 101);
    final handing = HandingIn();

    final placed = await handing.give(backend, task, file.path);

    expect(placed, isNull);
    expect(handing.failed, isTrue);
    expect(handing.said, contains('at most 100 bytes'));
    expect(backend.parts, 0, reason: 'refused here, before a byte of it was read or sent');
  });

  test('a file taken back is gone from the task, and the record keeps both', () async {
    final task = await aRunningTask();
    final file = await aFile('brief.md', 40);
    final handing = HandingIn();
    await handing.give(backend, task, file.path);

    final current = (await backend.tasks()).firstWhere((each) => each.name == task.name);
    final taken = await handing.takeBack(backend, current, 'brief.md');

    expect(taken?.name, 'brief.md', reason: handing.said);
    final listed = (await backend.tasks()).firstWhere((each) => each.name == task.name);
    expect(listed.files, isEmpty);
    expect((await backend.handIns(task.name)).map((each) => each.event), ['given', 'taken back']);
  });

  test('a refusal is said in its own words, with what to do', () async {
    final task = await aRunningTask();
    final file = await aFile('.hidden', 10);
    final handing = HandingIn();

    await handing.give(backend, task, file.path);

    expect(handing.failed, isTrue);
    expect(handing.said, contains('will not take the name ".hidden"'));
    expect(handing.said, contains('another name'));
  });

  test('a machine without hand-in says so rather than failing', () async {
    daemon.remove('HandIn');
    final task = await aRunningTask();
    final file = await aFile('notes.txt', 10);
    final handing = HandingIn();

    await handing.give(backend, task, file.path);

    expect(handing.said, 'This machine cannot hand a file to work.');
  });
}

/// The real backend, counting the parts it sends.
class _Counting extends SokarBackend {
  _Counting(super.backend);

  int parts = 0;

  @override
  Future<HandInPart> handIn(String task,
      {required String name,
      required int bytes,
      required String sha256,
      required int offset,
      required List<int> part}) {
    parts++;
    return super.handIn(task, name: name, bytes: bytes, sha256: sha256, offset: offset, part: part);
  }
}
