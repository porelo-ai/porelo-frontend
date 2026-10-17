// Linux only: it reads the file's mode with stat, which Windows has no such thing as.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/notifications.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/app/settings.dart';

/// What was run, kept between runs of the window.
///
/// The window is closed and opened again by building a second [Operations] over the same store,
/// which is all a restart leaves behind.
void main() {
  final today = DateTime(2026, 9, 13, 14);

  Operations over(OperationsStore store, {DateTime? now}) =>
      Operations(store: store, now: () => now ?? today, saveDelay: Duration.zero);

  Map<String, Object?> stored(String id, DateTime startedAt, {String state = 'succeeded'}) =>
      <String, Object?>{
        'id': id,
        'title': 'Build the environment for checkout',
        'machine': 'this machine',
        'startedAt': startedAt.toUtc().toIso8601String(),
        'state': state,
        'summary': 'Finished.',
        'seen': false,
        'output': <String>['one line'],
      };

  test('what was run comes back after a restart, marked as earlier, with what it printed', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    final output = StreamController<String>();
    before.run(title: 'Start Porelo on user@build', machine: 'the build machine', output: output.stream);
    output
      ..add('ssh user@build …')
      ..addError(const FailedSaying('systemd refused to start porelod (exit 1)'));
    await output.close();
    await before.flush();

    final after = over(store);
    await after.load();

    final back = after.all.single;
    expect(back.fromBefore, isTrue);
    expect(back.failed, isTrue);
    expect(back.machine, 'the build machine');
    expect(back.summary, 'systemd refused to start porelod (exit 1)');
    expect(back.output, <String>['ssh user@build …']);
    expect(back.seen, isFalse, reason: 'nobody opened it before the window closed');
  });

  test('a failure that was seen comes back as seen', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    final output = StreamController<String>();
    final operation = before.run(title: 'Build', output: output.stream);
    output.addError(const FailedSaying('it broke'));
    await output.close();
    await Future<void>.delayed(Duration.zero);
    before.see(operation);
    await before.flush();

    final after = over(store);
    await after.load();

    expect(after.all.single.seen, isTrue);
  });

  test('anything older than thirty days is dropped, and how many is said', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[
      stored('operation-1', today.subtract(const Duration(days: 31))),
      stored('operation-2', today.subtract(const Duration(days: 29))),
    ]);

    final after = over(store);
    await after.load();

    expect(after.all.map((each) => each.id), <String>['operation-2']);
    expect(after.droppedAsOld, 1);
    await after.flush();
    expect(await store.read(), hasLength(1), reason: 'what was dropped is still in the file');
  });

  test('an operation still running when the window closed is not reported as having gone well', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[stored('operation-1', today, state: 'running')]);

    final after = over(store);
    await after.load();

    final back = after.all.single;
    expect(back.running, isFalse, reason: 'nothing is watching it any more');
    expect(back.failed, isTrue);
    expect(back.summary, contains('how it ended is not known'));
  });

  test('a long output keeps its last lines and says how many it did not keep', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    final output = StreamController<String>();
    before.run(title: 'Build', output: output.stream);
    for (var line = 1; line <= Operations.linesKept + 500; line++) {
      output.add('line $line');
    }
    await output.close();
    await Future<void>.delayed(Duration.zero);
    await before.flush();

    final after = over(store);
    await after.load();

    final back = after.all.single;
    expect(back.output, hasLength(Operations.linesKept));
    expect(back.output.last, 'line ${Operations.linesKept + 500}');
    expect(back.linesNotKept, 500);
  });

  test('a new operation never takes the id of one from before', () async {
    // The ids a counter starting again from nothing would hand out first.
    final store = MemoryOperationsStore();
    await store.write(<Object?>[stored('operation-1', today), stored('operation-2', today)]);
    final after = over(store);
    await after.load();

    final added = after.run(title: 'Build', output: const Stream<String>.empty());

    expect(added.id, isNot(anyOf('operation-1', 'operation-2')));
    expect(after.byId('operation-1')!.fromBefore, isTrue);
  });

  test('a busy operation is written once for many lines, not once per line', () async {
    final store = MemoryOperationsStore();
    final busy = Operations(store: store, now: () => today, saveDelay: const Duration(milliseconds: 50));
    final output = StreamController<String>();
    busy.run(title: 'Build', output: output.stream);
    await Future<void>.delayed(Duration.zero);
    final atStart = store.writes;
    for (var line = 0; line < 200; line++) {
      output.add('line $line');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(store.writes - atStart, inInclusiveRange(1, 2), reason: 'gathered, and still written');
    await output.close();
    busy.dispose();
  });

  test('a record that does not say what it needs to is left out, not fatal', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[
      'not a record',
      <String, Object?>{'id': 'operation-1'},
      stored('operation-2', today, state: 'something new'),
      stored('operation-3', today),
    ]);

    final after = over(store);
    await after.load();

    expect(after.all.map((each) => each.id), <String>['operation-3']);
  });

  group('the file', () {
    late Directory where;
    late File file;

    setUp(() {
      where = Directory.systemTemp.createTempSync('porelo-operations-test');
      file = File('${where.path}/porelo/operations.json');
      addTearDown(() {
        if (where.existsSync()) where.deleteSync(recursive: true);
      });
    });

    test('is readable by nobody but its owner', () async {
      await FileOperationsStore(file: file).write(<Object?>[stored('operation-1', today)]);

      expect(FileStat.statSync(file.path).mode & 0x3F, 0, reason: 'what was run names hosts');
    });

    test('is replaced in one step, never written into, and leaves nothing beside it', () async {
      final store = FileOperationsStore(file: file);
      await store.write(<Object?>[stored('operation-1', today)]);
      final before = Process.runSync('stat', <String>['-c', '%i', file.path]).stdout;

      await store.write(<Object?>[stored('operation-2', today)]);

      expect(Process.runSync('stat', <String>['-c', '%i', file.path]).stdout, isNot(before));
      expect(file.parent.listSync().map((each) => each.path.split('/').last), <String>['operations.json']);
    });

    test('that cannot be read is a window that has run nothing yet', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{"operations": [trunc');

      expect(await FileOperationsStore(file: file).read(), isEmpty);
    });
  });

  // A fresh window has announced nothing yet, so only the operation itself can say it was said.
  test('nothing read back is announced again when the window opens, and a failure now still is', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[stored('operation-1', today, state: 'failed')]);
    final after = over(store);
    final notifier = _Recording();
    final settings = Settings(MemorySettingsStore());
    await settings.load();
    final notifications = Notifications(notifier, settings)..watchOperations(after, open: (_) {});
    addTearDown(notifications.dispose);
    await notifications.load();

    await after.load();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.raised, isEmpty, reason: "yesterday's failure was announced on opening the window");

    final output = StreamController<String>();
    after.run(title: 'Build', output: output.stream);
    output.addError(const FailedSaying('it broke'));
    await output.close();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.raised, hasLength(1));
  });

  test('opening the file asks the desktop to open that path', () async {
    final opened = <String>[];
    final record = Operations(
      store: MemoryOperationsStore(file: File('/home/somebody/.local/state/porelo/operations.json')),
      open: (path) async => opened.add(path),
    );

    await record.openTheFile();

    expect(opened, <String>['/home/somebody/.local/state/porelo/operations.json']);
  });
}

class _Recording implements Notifier {
  final List<Announcement> raised = <Announcement>[];

  @override
  String? problem;

  @override
  Future<void> raise(Announcement note, {required VoidCallback onOpened}) async => raised.add(note);
}
