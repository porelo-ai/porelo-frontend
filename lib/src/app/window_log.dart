import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'desk.dart';

/// How much a log entry matters, least first. The log keeps an entry at the level in force or above.
enum LogLevel {
  /// What the window asked and was answered.
  debug('DEBUG'),

  /// What a refresh, a start or a person's decision did, and what left *Needs you*.
  info('INFO'),

  /// A call to a machine that failed, or what the window could not do.
  warn('WARN'),

  /// What the window itself got wrong.
  error('ERROR');

  const LogLevel(this.word);

  /// How the level reads in a line of the log.
  final String word;
}

/// The window's own log, `frontend.log` in `logs` under the window's state folder, beside the planner's.
///
/// **One line per entry**: its time in UTC, its level, the machine it is about where there is one, and its words. A
/// line break in the words is written as `\n`, so one entry never reads as two. Only what the window shows a person
/// anyway is written, never a credential's value.
///
/// **Bounded**: past [maxBytes] the file becomes `frontend.log.1`, the older ones move up one, and only [kept] of
/// them stay.
///
/// **Never in the way**: a folder that cannot be written is said once, on standard error, and the window goes on
/// without its log.
class WindowLog {
  /// A log writing into [directory] at [level], INFO where none is given. [clock], [complain] and [keepPrivate] are
  /// for a test.
  WindowLog(
    String this.directory, {
    ValueListenable<LogLevel>? level,
    DateTime Function()? clock,
    this.maxBytes = 10 * 1024 * 1024,
    this.kept = 3,
    void Function(String words)? complain,
    Future<void> Function(String directory)? keepPrivate,
  }) : level = level ?? ValueNotifier<LogLevel>(LogLevel.info),
       _clock = clock ?? DateTime.now,
       _complain = complain ?? stderr.writeln,
       _keepPrivate = keepPrivate ?? ((path) => desk.keepPrivate(path, directory: true));

  /// A log that writes nothing: what the window uses until it named its folder, and what a test sees unless it sets
  /// one, so no test writes into a person's state folder.
  WindowLog.off()
    : directory = null,
      level = ValueNotifier<LogLevel>(LogLevel.info),
      maxBytes = 0,
      kept = 0,
      _clock = DateTime.now,
      _complain = _quiet,
      _keepPrivate = _none;

  /// The name of the file written now.
  static const fileName = 'frontend.log';

  /// The folder the log is written into, or null for a log that writes nothing.
  final String? directory;

  /// The level in force, read at every entry, so a change counts from the next one.
  final ValueListenable<LogLevel> level;

  /// How long one file grows, in bytes, before a new one is started.
  final int maxBytes;

  /// How many older files are kept.
  final int kept;

  final DateTime Function() _clock;
  final void Function(String words) _complain;
  final Future<void> Function(String directory) _keepPrivate;

  bool _ready = false;
  bool _complained = false;
  int _size = 0;

  /// What the window asked and was answered.
  void debug(String words, {String? machine}) => write(LogLevel.debug, words, machine: machine);

  /// What a refresh, a start or a decision did.
  void info(String words, {String? machine}) => write(LogLevel.info, words, machine: machine);

  /// What failed on a machine or could not be done.
  void warn(String words, {String? machine}) => write(LogLevel.warn, words, machine: machine);

  /// What the window itself got wrong.
  void error(String words, {String? machine}) => write(LogLevel.error, words, machine: machine);

  /// Writes [words] at [at], about [machine] where there is one, when [at] is at the level in force or above.
  void write(LogLevel at, String words, {String? machine}) {
    final folder = directory;
    if (folder == null || at.index < level.value.index) return;
    final about = machine == null || machine.isEmpty ? '' : '[${_oneLine(machine)}] ';
    final now = DateTime.fromMillisecondsSinceEpoch(_clock().millisecondsSinceEpoch, isUtc: true);
    final line = '${now.toIso8601String()} ${at.word.padRight(5)} $about${_oneLine(words)}\n';
    try {
      _prepare(folder);
      final bytes = utf8.encode(line).length;
      final file = File('$folder/$fileName');
      if (_size + bytes > maxBytes) {
        // Another window may have written to it, or started it anew: its own length decides, not this count.
        _size = file.existsSync() ? file.lengthSync() : 0;
        if (_size > 0 && _size + bytes > maxBytes) _rotate(folder);
      }
      file.writeAsStringSync(line, mode: FileMode.append);
      _size += bytes;
    } on FileSystemException catch (failure) {
      _ready = false;
      if (_complained) return;
      _complained = true;
      _complain('Porelo cannot write its log in $folder, and goes on without it: ${failure.message}.');
    }
  }

  void _prepare(String folder) {
    if (_ready) return;
    final logs = Directory(folder);
    if (!logs.existsSync()) {
      logs.createSync(recursive: true);
      _keepPrivate(folder).ignore();
    }
    final file = File('$folder/$fileName');
    _size = file.existsSync() ? file.lengthSync() : 0;
    _ready = true;
  }

  void _rotate(String folder) {
    String named(int index) => index == 0 ? '$folder/$fileName' : '$folder/$fileName.$index';
    final oldest = File(named(kept));
    if (oldest.existsSync()) oldest.deleteSync();
    for (var index = kept - 1; index >= 0; index--) {
      final file = File(named(index));
      if (file.existsSync()) file.renameSync(named(index + 1));
    }
    _size = 0;
  }

  static String _oneLine(String words) => words.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

  static void _quiet(String _) {}

  static Future<void> _none(String _) async {}
}

/// The folder the window's log is written into: `logs` under the window's state folder on [desk].
String windowLogFolder(Desk desk) => desk.join(<String>[desk.state, 'logs']);

/// The file the window writes its log into now, in [windowLogFolder].
String windowLogFile(Desk desk) => desk.join(<String>[windowLogFolder(desk), WindowLog.fileName]);

/// The window's log. Off until `main` names its folder; a test that reads the log sets one of its own and puts this
/// back.
WindowLog windowLog = WindowLog.off();
