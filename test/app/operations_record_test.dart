// Linux only: it reads the file's mode with stat, which Windows has no such thing as.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
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

  Map<String, Object?> stored(String id, DateTime startedAt, {String state = 'succeeded'}) => <String, Object?>{
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
    await back.openAtEnd();
    expect(back.fromBefore, isTrue);
    expect(back.failed, isTrue);
    expect(back.machine, 'the build machine');
    expect(back.summary, 'systemd refused to start porelod (exit 1)');
    expect(back.output, <String>['ssh user@build …']);
    expect(back.seen, isFalse, reason: 'nobody opened it before the window closed');
  });

  // Harm: a start that answers after the window closed writes the record again behind the one written as it closed,
  // or throws into nothing.
  test('an operation that goes on after the window closed writes nothing more', () async {
    final store = MemoryOperationsStore();
    final operations = over(store);
    final output = StreamController<String>();
    operations.dispose();
    final written = store.writes;

    operations.run(title: 'Discuss an idea in checkout', machine: 'this machine', output: output.stream);
    output
      ..add('Building the image')
      ..addError(const FailedSaying('it broke'));
    await output.close();
    await pumpEventQueue();

    expect(store.writes, written, reason: 'nothing written after the window closed');
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
    await back.openAtEnd();
    expect(back.running, isFalse, reason: 'nothing is watching it any more');
    expect(back.failed, isTrue);
    expect(back.summary, contains('how it ended is not known'));
  });

  // Harm: a long build's first lines are dropped from the record, so what started it can never be read again.
  test('a long output is kept whole, and a record read back holds only its end', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    final output = StreamController<String>();
    before.run(title: 'Build', output: output.stream);
    const total = Operation.pageLines * 5 + 7;
    for (var line = 1; line <= total; line++) {
      output.add('line $line');
    }
    await output.close();
    await Future<void>.delayed(Duration.zero);
    await before.flush();

    expect(store.printed.values.single, hasLength(total), reason: 'every line is in the record');
    final after = over(store);
    await after.load();

    final back = after.all.single;
    await back.openAtEnd();
    expect(back.output, hasLength(Operation.pageLines));
    expect(back.output.last, 'line $total');
    expect(back.hasOlder, isTrue);
  });

  // Harm: reading older lines drops the lines being read, or never reaches the start of the record, or lets
  // the held lines grow with every page.
  test('older lines are read until the start, and only a bounded window is held', () async {
    final store = MemoryOperationsStore();
    const total = Operation.windowLines + Operation.pageLines * 3 + 11;
    await store.write(<Object?>[stored('operation-1', today)]);
    await store.appendOutput('operation-1', <String>[for (var line = 1; line <= total; line++) 'line $line']);
    final after = over(store);
    await after.load();
    final back = after.all.single;
    await back.openAtEnd();
    expect(back.output.first, 'line ${total - Operation.pageLines + 1}');

    var reads = 0;
    while (back.hasOlder) {
      expect(await back.loadOlder(), isTrue);
      expect(back.output.length, lessThanOrEqualTo(Operation.windowLines));
      reads++;
    }

    expect(back.output.first, 'line 1', reason: 'the start of the record is reached');
    expect(reads, greaterThan(Operation.windowLines ~/ Operation.pageLines), reason: 'more than one window was read');
    expect(back.hasNewer, isTrue, reason: 'the end was let go of, and can be read again');
    while (back.hasNewer) {
      await back.loadNewer();
      expect(back.output.length, lessThanOrEqualTo(Operation.windowLines));
    }
    expect(back.output.last, 'line $total');
  });

  // Harm: reading a record file in pages holds, or mis-cuts, a line that straddles a chunk or has odd text in it.
  test('a record file is read in pages from both ends without loading all of it', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('record');
    addTearDown(() => folder.delete(recursive: true));
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));
    final lines = <String>[
      for (var line = 0; line < 3000; line++) 'line $line ${'é' * (line % 400)}${line % 97 == 0 ? '\nbroken' : ''}',
    ];
    await store.appendOutput('operation-1', lines.sublist(0, 1500));
    await store.appendOutput('operation-1', lines.sublist(1500));

    final source = (await store.outputOf('operation-1'))!;
    final end = await source.size();
    final tail = await source.before(end, 250);
    expect(tail.lines, lines.sublist(2750));

    final head = await source.after(0, 250);
    expect(head.lines, lines.sublist(0, 250));
    final more = await source.after(head.ends.last, 4000);
    expect(more.lines, lines.sublist(250), reason: 'forward reading goes to the end and stops');

    var position = end;
    final back = <String>[];
    while (position > 0) {
      final page = await source.before(position, 333);
      back.insertAll(0, page.lines);
      position = page.start;
    }
    expect(back, lines);
    expect(await store.outputOf('operation-2'), isNull, reason: 'what was never printed is absent, not empty');
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

    // Harm: a file that cannot be read is taken for one that holds nothing, and what it names is deleted with it.
    test('that cannot be read is said by a throw, not taken for a window that has run nothing', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{"operations": [trunc');

      await expectLater(FileOperationsStore(file: file).read(), throwsFormatException);
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
  // Harm: a run whose output file is gone reads as one that printed nothing.
  test('a record whose output file is missing says its lines are missing, not that none were printed', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    final output = StreamController<String>();
    before.run(title: 'Build', output: output.stream);
    output
      ..add('one')
      ..add('two');
    await output.close();
    await Future<void>.delayed(Duration.zero);
    await before.flush();
    await store.deleteOutput('operation-1');

    final after = over(store);
    await after.load();

    await after.all.single.openAtEnd();

    expect(after.all.single.linesMissing, isTrue);
    expect(after.all.single.linesPrinted, 2);
  });

  // Harm: a run that printed nothing is reported as having lost its lines.
  test('a run that printed nothing is not reported as missing lines', () async {
    final store = MemoryOperationsStore();
    final before = over(store);
    before.run(title: 'Build', output: const Stream<String>.empty());
    await Future<void>.delayed(Duration.zero);
    await before.flush();

    final after = over(store);
    await after.load();

    await after.all.single.openAtEnd();

    expect(after.all.single.linesMissing, isFalse);
    expect(after.all.single.linesPrinted, 0);
  });

  // Harm: "Try again" after the record failed to open does nothing, so the lines stay unreadable.
  test('a record that failed to open is opened again on request', () async {
    final store = _FailsOnce();
    await store.write(<Object?>[stored('operation-1', today)]);
    await store.appendOutput('operation-1', <String>['kept']);
    final after = over(store);
    await after.load();
    final back = after.all.single;
    await back.openAtEnd();
    expect(back.readProblem, isNotNull);
    expect(back.output, isEmpty);

    await back.openAtEnd();

    expect(back.readProblem, isNull);
    expect(back.output, <String>['kept']);
  });

  // Harm: a new operation appends onto the lines of an old one that has its id, after the record could not be read.
  test('a new operation never appends to a file an earlier one left under its id', () async {
    final store = MemoryOperationsStore();
    await store.appendOutput('operation-1', <String>['old']);
    final fresh = over(store);
    final output = StreamController<String>();
    fresh.run(title: 'Build', output: output.stream);
    output.add('new');
    await output.close();
    await Future<void>.delayed(Duration.zero);
    await fresh.flush();

    expect(store.printed['operation-1'], <String>['new']);
  });

  // Harm: output files of records that no longer exist pile up and later meet a reused id.
  test('output files that belong to no record are removed when the record is read', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[stored('operation-1', today)]);
    await store.appendOutput('operation-1', <String>['mine']);
    await store.appendOutput('operation-9', <String>['nobody\'s']);

    await over(store).load();

    expect(store.printed.keys, <String>['operation-1']);
  });

  // Harm: an id that is not one the window made names a file outside the folder, or one file for two ids.
  test('only ids the window made name a record file', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('ids');
    addTearDown(() => folder.delete(recursive: true));
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));

    expect(() => store.appendOutput('../escape', <String>['x']), throwsArgumentError);
    expect(() => store.appendOutput('a/b', <String>['x']), throwsArgumentError);
    expect(Operation.fromStored(stored('../escape', today)), isNull);
    expect(Operation.fromStored(stored('operation-1', today)), isNotNull);
  });

  // Harm: lines that could not be written leave a silent gap in a record that reads as whole.
  test('lines that could not be kept are counted in the record', () async {
    final store = _FailsToAppend();
    final before = over(store);
    final output = StreamController<String>();
    before.run(title: 'Build', output: output.stream);
    output
      ..add('one')
      ..add('two');
    await output.close();
    await Future<void>.delayed(Duration.zero);
    await before.flush();

    final after = over(store);
    await after.load();

    expect(after.all.single.linesLost, 2);
  });

  // Harm: a folder or file left open to others by a failed first chmod stays open, as it is only made private
  // when it is created.
  test('an existing output folder and file are made private on first use', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('modes');
    addTearDown(() => folder.delete(recursive: true));
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));
    await store.outputFolder.create();
    await Process.run('chmod', <String>['777', store.outputFolder.path]);
    final file = File('${store.outputFolder.path}/operation-1.jsonl')..writeAsStringSync('');
    await Process.run('chmod', <String>['666', file.path]);

    expect(await store.appendOutput('operation-1', <String>['secret']), isTrue);

    expect(store.outputFolder.statSync().mode & 0x1ff, 448, reason: 'rwx------');
    expect(file.statSync().mode & 0x1ff, 384, reason: 'rw-------');
  });
  // Harm: a read that failed, or a file that is corrupt, is taken for a record that holds nothing, and every file of
  // what was printed is deleted with it.
  test('a record that could not be read whole costs no file of what was printed', () async {
    final store = _FailsToRead();
    await store.appendOutput('operation-1', <String>['mine']);

    await over(store).load();

    expect(store.printed['operation-1'], <String>['mine']);
  });

  // Harm: a record that is not understood loses its file, so a fix of the reader cannot get it back.
  test('the file of a record that is not understood is kept', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[
      stored('operation-1', today),
      <String, Object?>{'id': 'operation-2', 'title': 7},
    ]);
    await store.appendOutput('operation-1', <String>['one']);
    await store.appendOutput('operation-2', <String>['two']);

    final after = over(store);
    await after.load();
    after.run(title: 'Build', output: const Stream<String>.empty());

    expect(store.printed.keys, containsAll(<String>['operation-1', 'operation-2']));
    expect(after.all.last.id, 'operation-3', reason: 'the id of a record that is not understood is not handed out');
  });

  // Harm: a file that is there and empty, or short, reads as a run that printed nothing.
  test('a record file that is empty or shorter than the record says is reported as missing lines', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[
      <String, Object?>{...stored('operation-1', today), 'lines': 5},
      <String, Object?>{...stored('operation-2', today), 'lines': 5},
      <String, Object?>{...stored('operation-3', today), 'lines': 5},
    ]);
    await store.appendOutput('operation-1', <String>[]);
    await store.appendOutput('operation-2', <String>['a', 'b', 'c']);
    await store.appendOutput('operation-3', <String>['a', 'b', 'c', 'd', 'e']);
    final after = over(store);
    await after.load();
    for (final each in after.all) {
      await each.openAtEnd();
    }

    expect(after.byId('operation-1')!.linesGone, 5);
    expect(after.byId('operation-2')!.linesGone, 2);
    expect(after.byId('operation-3')!.linesMissing, isFalse);
  });

  // Harm: a file that is there and cannot be opened reads as a file that is not there, with no way to try again.
  test('a record file that cannot be opened is told apart from one that is not there', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('open');
    addTearDown(() async {
      await Process.run('chmod', <String>['700', '${folder.path}/operations.json.output']);
      await folder.delete(recursive: true);
    });
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));
    await store.appendOutput('operation-1', <String>['x']);

    expect(await store.outputOf('operation-2'), isNull);
    await Process.run('chmod', <String>['000', store.outputFolder.path]);

    await expectLater(store.outputOf('operation-1'), throwsA(isA<FileSystemException>()));
  });

  // Harm: a window that was shown once is shown again from where the reader left it, with the newest lines let go.
  test('a record is opened at its end each time, whatever the window held before', () async {
    final store = MemoryOperationsStore();
    await store.write(<Object?>[stored('operation-1', today)]);
    const total = Operation.windowLines + Operation.pageLines * 2;
    await store.appendOutput('operation-1', <String>[for (var line = 1; line <= total; line++) 'line $line']);
    final after = over(store);
    await after.load();
    final back = after.all.single;
    await back.openAtEnd();
    while (back.hasOlder) {
      await back.loadOlder();
    }
    expect(back.output.last, isNot('line $total'), reason: 'the newest lines were let go');

    await back.openAtEnd();

    expect(back.output.last, 'line $total');
    expect(back.anchor, 0);
    expect(back.hasOlder, isTrue);
  });

  // Harm: every kept record reads a page of its file at startup, though only one at a time is ever shown.
  test('nothing of what was printed is read until a record is shown', () async {
    final store = _Counting();
    await store.write(<Object?>[stored('operation-1', today), stored('operation-2', today)]);
    await store.appendOutput('operation-1', <String>['a']);
    await store.appendOutput('operation-2', <String>['b']);

    final after = over(store);
    await after.load();

    expect(store.looked, 0);
    await after.byId('operation-1')!.openAtEnd();
    expect(store.looked, 1);
  });

  // Harm: a chmod that failed is taken for a file that is private, or a failed one is never tried again.
  test('lines are not written where the file could not be made private, and it is tried again', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('priv');
    final before = desk;
    var exit = 1;
    final asked = <String>[];
    desk = Desk.of(
      'linux',
      const <String, String>{},
      run: (executable, arguments) async {
        asked.add(arguments.last);
        return ProcessResult(0, exit, '', 'refused');
      },
    );
    addTearDown(() async {
      desk = before;
      await folder.delete(recursive: true);
    });
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));

    expect(await store.appendOutput('operation-1', <String>['secret']), isFalse);
    expect(
      File('${store.outputFolder.path}/operation-1.jsonl').existsSync()
          ? File('${store.outputFolder.path}/operation-1.jsonl').readAsStringSync()
          : '',
      isEmpty,
    );

    exit = 0;
    expect(await store.appendOutput('operation-1', <String>['secret']), isTrue);
    asked.clear();
    expect(await store.appendOutput('operation-1', <String>['more']), isTrue);
    expect(asked, isEmpty, reason: 'once it worked it is not asked again');

    await store.outputFolder.delete(recursive: true);
    expect(await store.appendOutput('operation-1', <String>['again']), isTrue);
    expect(asked, contains(store.outputFolder.path), reason: 'a folder made again is made private again');
  });

  // Harm: an append that failed halfway leaves bytes that glue onto the next line, and two lines read as one.
  test('a line that was left unended does not take the next one with it', () async {
    final folder = await Directory(Platform.environment['TMPDIR'] ?? Directory.systemTemp.path).createTemp('half');
    addTearDown(() => folder.delete(recursive: true));
    final store = FileOperationsStore(file: File('${folder.path}/operations.json'));
    await store.appendOutput('operation-1', <String>['first']);
    File('${store.outputFolder.path}/operation-1.jsonl').writeAsStringSync('"half', mode: FileMode.append);
    // A new store: it knows nothing of what the one before wrote.
    final again = FileOperationsStore(file: File('${folder.path}/operations.json'));

    await again.appendOutput('operation-1', <String>['next']);

    final source = (await again.outputOf('operation-1'))!;
    final page = await source.before(await source.size(), 10);
    expect(page.lines.last, 'next');
    expect(page.lines, hasLength(3));
  });
}

class _Recording implements Notifier {
  final List<Announcement> raised = <Announcement>[];

  @override
  String? problem;

  @override
  Future<void> raise(Announcement note, {required VoidCallback onOpened}) async => raised.add(note);
}

/// A store whose first look at a record's lines fails, as a disk that answers late would.
class _FailsOnce extends MemoryOperationsStore {
  bool _failed = false;

  @override
  Future<OutputSource?> outputOf(String id) async {
    if (!_failed) {
      _failed = true;
      throw const FileSystemException('Permission denied');
    }
    return super.outputOf(id);
  }
}

/// A store that cannot keep any line.
class _FailsToAppend extends MemoryOperationsStore {
  @override
  Future<bool> appendOutput(String id, List<String> lines) async => false;
}

/// A store whose record of what was run cannot be read.
class _FailsToRead extends MemoryOperationsStore {
  @override
  Future<List<Object?>> read() async => throw const FormatException('truncated');
}

/// A store that counts how often a record's file is looked for.
class _Counting extends MemoryOperationsStore {
  int looked = 0;

  @override
  Future<OutputSource?> outputOf(String id) {
    looked++;
    return super.outputOf(id);
  }
}
