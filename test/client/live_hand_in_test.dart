import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/hand_in.dart';

/// Hands files to a running task on a real machine, through the same code the interface uses.
///
/// Runs only when `PORELO_SOCKET` names a daemon's socket and `PORELO_HAND_IN_TASK` a running task on
/// it; it leaves `big.bin` and `resumed.bin` in that task for the content to be compared inside.
/// With `PORELO_HAND_IN_REMOVE=1` it instead stops and removes that task and reads its record.
void main() {
  final socket = Platform.environment['PORELO_SOCKET'] ?? '';
  final task = Platform.environment['PORELO_HAND_IN_TASK'] ?? '';
  final remove = Platform.environment['PORELO_HAND_IN_REMOVE'] == '1';
  final skip = socket.isEmpty || task.isEmpty
      ? 'needs PORELO_SOCKET and PORELO_HAND_IN_TASK, a running task on that machine'
      : null;

  late _Counting backend;
  late Directory here;

  setUp(() async {
    backend = _Counting(Backend(socketPath: socket, label: 'live'));
    await backend.open();
    here = await Directory.systemTemp.createTemp('live-hand-in-');
  });

  tearDown(() => here.delete(recursive: true));

  Future<Task> theTask() async => (await backend.tasks()).firstWhere((each) => each.name == task);

  Future<File> aFile(String name, int bytes) async {
    final file = File('${here.path}/$name');
    await file.writeAsBytes(List<int>.generate(bytes, (i) => (i * 31 + 7) % 251));
    return file;
  }

  String sha256Of(List<int> content) => crypto.sha256.convert(content).toString();

  group('against a running task', () {
    test('a small file is placed whole, listed with who handed it in', () async {
      final file = await aFile('small.txt', 100);
      final handing = HandingIn();

      final placed = await handing.give(backend, await theTask(), file.path);

      expect(placed, isNotNull, reason: handing.said);
      expect(placed!.sha256, sha256Of(await file.readAsBytes()));
      expect(placed.by, isNot(HandedFile.porelo));
      expect((await theTask()).files!.map((each) => each.name), contains('small.txt'));
    });

    test('a large file goes in parts and is placed whole', () async {
      final size = HandingIn.partBytes * 5 + 3;
      final file = await aFile('big.bin', size);
      backend.parts = 0;

      final placed = await HandingIn().give(backend, await theTask(), file.path);

      expect(backend.parts, 6, reason: 'five whole parts and the rest');
      expect(placed?.bytes, size);
      expect(placed?.sha256, sha256Of(await file.readAsBytes()));
    });

    test('a transfer cut off after one part resumes where the machine holds it', () async {
      final file = await aFile('resumed.bin', HandingIn.partBytes * 2 + 17);
      final content = await file.readAsBytes();
      await backend.handIn(
        task,
        name: 'resumed.bin',
        bytes: content.length,
        sha256: sha256Of(content),
        offset: 0,
        part: content.sublist(0, HandingIn.partBytes),
      );
      backend.parts = 0;
      final handing = HandingIn();

      final placed = await handing.give(backend, await theTask(), file.path);

      expect(placed?.sha256, sha256Of(content), reason: handing.said);
      expect(backend.parts, 3, reason: 'one refused at offset 0, then the two still missing');
    });

    test('a second file under a name still in flight is refused, with how far the first got', () async {
      final first = await aFile('busy.bin', HandingIn.partBytes * 2);
      final content = await first.readAsBytes();
      await backend.handIn(
        task,
        name: 'busy.bin',
        bytes: content.length,
        sha256: sha256Of(content),
        offset: 0,
        part: content.sublist(0, HandingIn.partBytes),
      );
      final other = await aFile('other.bin', 10);
      final handing = HandingIn();

      await handing.give(backend, await theTask(), other.path, as: 'busy.bin');

      expect(handing.said, contains('is being handed in: 1 MiB of 2 MiB are there'));
    });

    test('a file over the task\'s limit is refused before a byte is sent', () async {
      final to = await theTask();
      final limit = to.handInLimit!;
      final file = File('${here.path}/too-big.bin');
      final writing = await file.open(mode: FileMode.write);
      await writing.setPosition(limit);
      await writing.writeByte(0);
      await writing.close();
      backend.parts = 0;
      final handing = HandingIn();

      await handing.give(backend, to, file.path);

      expect(backend.parts, 0);
      expect(handing.said, contains('takes at most ${HandingIn.inWords(limit)}'));
    });

    test('a file taken back is gone, and the record says given and taken back', () async {
      final handing = HandingIn();
      // Its own file, so it does not need the first test to have run: it is given, then taken back.
      if (!(await theTask()).files!.any((each) => each.name == 'small.txt')) {
        await handing.give(backend, await theTask(), (await aFile('small.txt', 300)).path);
      }

      final taken = await handing.takeBack(backend, await theTask(), 'small.txt');

      expect(taken?.name, 'small.txt', reason: handing.said);
      expect((await theTask()).files!.map((each) => each.name), isNot(contains('small.txt')));
      final small = (await backend.handIns(task)).where((each) => each.file.name == 'small.txt');
      expect(small.map((each) => each.event).toList().reversed.take(2), ['taken back', 'given']);
    });

    test('a Watch opened before a hand-in sees the file arrive and go', () async {
      final events = <List<String>?>[];
      final seen = StreamController<List<String>?>.broadcast();
      final watching = backend.watch().listen((tasks) {
        final names = tasks.where((each) => each.name == task).firstOrNull?.files?.map((f) => f.name).toList();
        events.add(names);
        seen.add(names);
      });
      Future<void> until(bool Function(List<String>? names) holds, String what) => seen.stream
          .firstWhere(holds)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => fail('the open Watch never showed $what; it sent: $events'),
          );
      try {
        await until((names) => names != null, 'the task at all');
        final file = await aFile('watched.txt', 64);
        final handing = HandingIn();

        await handing.give(backend, await theTask(), file.path);
        await until((names) => names!.contains('watched.txt'), 'watched.txt handed in');
        await handing.takeBack(backend, await theTask(), 'watched.txt');
        await until((names) => !names!.contains('watched.txt'), 'watched.txt taken back');
      } finally {
        await watching.cancel();
        await seen.close();
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  }, skip: skip ?? (remove ? 'PORELO_HAND_IN_REMOVE is set' : null));

  test('the record is still there after the task is removed', () async {
    // Run again after a first run removed it, it only reads the record.
    if ((await backend.tasks()).any((each) => each.name == task)) {
      final client = await PoreloClient.connect(Backend(socketPath: socket, label: 'live'));
      await client.stop(task);
      await client.remove(task, force: true);
    }
    expect((await backend.tasks()).map((each) => each.name), isNot(contains(task)));

    final record = await backend.handIns(task);

    expect(record.map((each) => each.file.name), containsAll(['small.txt', 'big.bin']));
  }, skip: skip ?? (remove ? null : 'set PORELO_HAND_IN_REMOVE=1 to remove the task'));
}

/// The real backend, counting the parts it sends.
class _Counting extends PoreloBackend {
  _Counting(super.backend);

  int parts = 0;

  @override
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) {
    parts++;
    return super.handIn(task, name: name, bytes: bytes, sha256: sha256, offset: offset, part: part);
  }
}
