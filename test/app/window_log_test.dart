import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/window_log.dart';

void main() {
  late Directory scratch;
  setUp(() => scratch = Directory.systemTemp.createTempSync('window-log-'));
  tearDown(() => scratch.deleteSync(recursive: true));

  String logs() => '${scratch.path}/logs';
  List<String> lines([String name = WindowLog.fileName]) => File('${logs()}/$name').readAsLinesSync();
  final at = DateTime.utc(2026, 11, 11, 9, 30, 5, 120);
  // A folder the log made takes its lines once it is closed to others, which is asked of the desk and answered later.
  Future<void> closed() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // Harm: an entry split over lines, or missing its time, level or machine, cannot be told apart from the next one
  // when a person reads what happened.
  test('each entry is one line with its time, level, machine and words', () async {
    final log = WindowLog(logs(), clock: () => at, keepPrivate: (_) async {});
    log.info('Connected to orchard.', machine: 'orchard');
    log.warn('Lost contact:\nthe tunnel closed.\r\nTrying again.');
    await closed();
    expect(lines(), <String>[
      '2026-11-11T09:30:05.120Z INFO  [orchard] Connected to orchard.',
      r'2026-11-11T09:30:05.120Z WARN  Lost contact:\nthe tunnel closed.\r\nTrying again.',
    ]);
  });

  // Harm: a log at a level nobody set either floods the disk with what was asked and answered, or keeps back what
  // a person raised the level to see; a change that waited for a restart would miss what was happening now.
  test('only entries at the level in force or above are written, and a change counts at once', () async {
    final level = ValueNotifier<LogLevel>(LogLevel.info);
    addTearDown(level.dispose);
    final log = WindowLog(logs(), level: level, clock: () => at, keepPrivate: (_) async {});
    log.debug('Asked orchard for its tasks.');
    log.info('Refreshed orchard.');
    level.value = LogLevel.debug;
    log.debug('Asked apple for its tasks.');
    level.value = LogLevel.error;
    log.warn('Cannot reach apple.');
    log.error('The settings could not be written.');
    await closed();
    expect(lines().map((line) => line.substring(25)), <String>[
      'INFO  Refreshed orchard.',
      'DEBUG Asked apple for its tasks.',
      'ERROR The settings could not be written.',
    ]);
  });

  test('the level is INFO where none is set', () {
    expect(WindowLog(logs()).level.value, LogLevel.info);
  });

  // Harm: a window left open for weeks fills the disk with its log.
  test('past its bound a new file is started and three older ones are kept', () async {
    final log = WindowLog(logs(), clock: () => at, maxBytes: 100, keepPrivate: (_) async {});
    for (var i = 0; i < 12; i++) {
      log.info('entry $i ${'x' * 40}');
    }
    await closed();
    final names = Directory(logs()).listSync().map((each) => each.uri.pathSegments.last).toList()..sort();
    expect(names, <String>['frontend.log', 'frontend.log.1', 'frontend.log.2', 'frontend.log.3']);
    for (final name in names) {
      expect(File('${logs()}/$name').lengthSync(), lessThanOrEqualTo(100), reason: '$name stays within the bound');
    }
    expect(lines().last, contains('entry 11 '), reason: 'the newest entry is in the current file');
    expect(lines('frontend.log.3').first, contains('entry 8 '), reason: 'the oldest kept is the one three files back');
  });

  // Harm: a second window writes to the same file and starts a new one; the first, counting only its own lines,
  // would start yet another too early and delete the oldest file kept.
  test('a file another writer started anew is not rotated early', () async {
    final log = WindowLog(logs(), clock: () => at, maxBytes: 100, keepPrivate: (_) async {});
    log.info('first ${'x' * 30}');
    await closed();
    File('${logs()}/${WindowLog.fileName}').renameSync('${logs()}/${WindowLog.fileName}.1');
    File('${logs()}/${WindowLog.fileName}').writeAsStringSync('');
    log.info('second ${'x' * 30}');
    expect(lines(), hasLength(1), reason: 'the new file takes the line');
    expect(File('${logs()}/${WindowLog.fileName}.2').existsSync(), isFalse, reason: 'nothing was rotated');
  });

  // Harm: the planner shares this folder; a line written into it before it is closed to others can be read by them.
  test('no line is written before the folder it made is closed to others, and none is lost', () async {
    final closing = Completer<void>();
    final log = WindowLog(logs(), clock: () => at, keepPrivate: (_) => closing.future);
    log.info('one');
    log.warn('two');
    await closed();
    expect(File('${logs()}/${WindowLog.fileName}').existsSync(), isFalse, reason: 'held until the folder is closed');

    closing.complete();
    await closed();
    log.info('three');
    expect(lines().map((line) => line.substring(25)), <String>['INFO  one', 'WARN  two', 'INFO  three']);
  });

  // Harm: a desk that cannot close the folder silences the window's log for good.
  test('a folder that could not be closed to others takes the lines all the same', () async {
    final log = WindowLog(logs(), clock: () => at, keepPrivate: (_) async => throw const FileSystemException('no'));
    log.info('one');
    await closed();
    expect(lines().map((line) => line.substring(25)), <String>['INFO  one']);
  });

  // Harm: a log that cannot be written stops the window, or says so on every line until the terminal is unreadable.
  test('a directory that cannot be written is said once, and the window goes on', () {
    File('${scratch.path}/blocked').writeAsStringSync('a file where the directory should be');
    final said = <String>[];
    final log = WindowLog('${scratch.path}/blocked/logs', clock: () => at, complain: said.add);
    log.info('first');
    log.warn('second');
    log.error('third');
    expect(said, hasLength(1));
    expect(said.single, contains('${scratch.path}/blocked/logs'));
  });

  test('a log that is off writes nothing anywhere', () {
    WindowLog.off().error('nothing');
    expect(Directory(logs()).existsSync(), isFalse);
  });

  test('a directory it makes is kept to its owner', () {
    final kept = <String>[];
    final log = WindowLog(logs(), keepPrivate: (path) async => kept.add(path));
    log.info('one');
    log.info('two');
    expect(kept, <String>[logs()]);
  });
}
