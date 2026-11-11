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

  // Harm: an entry split over lines, or missing its time, level or machine, cannot be told apart from the next one
  // when a person reads what happened.
  test('each entry is one line with its time, level, machine and words', () {
    final log = WindowLog(logs(), clock: () => at, keepPrivate: (_) async {});
    log.info('Connected to orchard.', machine: 'orchard');
    log.warn('Lost contact:\nthe tunnel closed.\r\nTrying again.');
    expect(lines(), <String>[
      '2026-11-11T09:30:05.120Z INFO  [orchard] Connected to orchard.',
      r'2026-11-11T09:30:05.120Z WARN  Lost contact:\nthe tunnel closed.\r\nTrying again.',
    ]);
  });

  // Harm: a log at a level nobody set either floods the disk with what was asked and answered, or keeps back what
  // a person raised the level to see; a change that waited for a restart would miss what was happening now.
  test('only entries at the level in force or above are written, and a change counts at once', () {
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
  test('past its bound a new file is started and three older ones are kept', () {
    final log = WindowLog(logs(), clock: () => at, maxBytes: 100, keepPrivate: (_) async {});
    for (var i = 0; i < 12; i++) {
      log.info('entry $i ${'x' * 40}');
    }
    final names = Directory(logs()).listSync().map((each) => each.uri.pathSegments.last).toList()..sort();
    expect(names, <String>['frontend.log', 'frontend.log.1', 'frontend.log.2', 'frontend.log.3']);
    for (final name in names) {
      expect(File('${logs()}/$name').lengthSync(), lessThanOrEqualTo(100), reason: '$name stays within the bound');
    }
    expect(lines().last, contains('entry 11 '), reason: 'the newest entry is in the current file');
    expect(lines('frontend.log.3').first, contains('entry 8 '), reason: 'the oldest kept is the one three files back');
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
