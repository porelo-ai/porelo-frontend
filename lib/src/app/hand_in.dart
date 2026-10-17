import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Handing a file on this computer to a running task, and taking one back.
///
/// **In parts, each a call of its own.** A request may be at most 4 MiB and a single call has a
/// deadline, so a file goes in parts well below both; a cut connection loses one part, and the
/// machine's `PartOutOfOrder` says where to go on. The file reaches the task only once the machine
/// has it whole and its SHA-256 matches, so nothing here is shown as handed in before the machine's
/// answer says so.
class HandingIn extends ChangeNotifier {
  /// The size of one part. Half the machine's recommended most, so one part stays well within a
  /// call's deadline over a forwarded socket.
  static const partBytes = 1024 * 1024;

  /// Lost connections in a row after which a hand-in stops rather than trying again.
  static const mostLostInARow = 3;

  /// Which task a hand-in is going to, or null when none is.
  String? task;

  /// The file's name in the task.
  String? name;

  /// Bytes the machine holds, as its last answer said.
  int received = 0;

  /// The whole file's size.
  int bytes = 0;

  /// Whether something is being sent or taken back right now.
  bool busy = false;

  /// What came of the last action, in words. Null before one.
  String? said;

  /// Whether [said] is a refusal or a failure rather than a result.
  bool failed = false;

  /// Whether [task] can be handed a file, and if not, why.
  ///
  /// A task that is not running has no container to hand a file to, and a machine without hand-in
  /// does not say how much it takes: both are knowable before anything is read.
  static String? whyNot(Task? task) {
    if (task == null) return 'no work is selected';
    if (task.handInLimit == null) return 'this machine cannot hand a file to work';
    if (!task.running) return 'it is not running, and a file goes only to running work';
    return null;
  }

  /// Why the files of [task] cannot be taken back, or null when they can.
  static String? whyNotTakeBack(Task? task) {
    if (task == null) return 'no work is selected';
    final files = task.files;
    if (files == null) return 'this machine cannot hand a file to work';
    if (!task.running) return 'it is not running, and only running work gives a file back';
    if (files.isEmpty) return 'nothing has been handed to it';
    return null;
  }

  /// Hands the file at [path] to [to] under [as], or under its own name.
  ///
  /// Refused before a byte is read when the file is larger than the task takes.
  Future<HandedFile?> give(FleetBackend backend, Task to, String path, {String? as}) async {
    final file = File(path);
    // Either separator: a picked file on Windows can come with `/` as well as `\\`.
    final named = as ?? path.split(RegExp(r'[\\/]')).last;
    final int size;
    try {
      size = await file.length();
    } on FileSystemException catch (ex) {
      task = to.name;
      name = named;
      _tell('$named cannot be read here: ${ex.osError?.message ?? ex.message}. Nothing was sent.', failed: true);
      return null;
    }
    task = to.name;
    name = named;
    bytes = size;
    received = 0;
    final limit = to.handInLimit;
    if (limit != null && size > limit) {
      _tell(
        '$named has ${inWords(size)}, and ${to.name} takes at most ${inWords(limit)}. '
        'Nothing was sent.',
        failed: true,
      );
      return null;
    }
    busy = true;
    said = null;
    failed = false;
    notifyListeners();
    RandomAccessFile? opened;
    try {
      opened = await file.open();
      final sha256 = (await crypto.sha256.bind(file.openRead()).first).toString();
      var offset = 0;
      var lostInARow = 0;
      var resumedAt = -1;
      while (true) {
        await opened.setPosition(offset);
        final part = await opened.read(min(partBytes, size - offset));
        try {
          final answer = await backend.handIn(
            to.name,
            name: named,
            bytes: size,
            sha256: sha256,
            offset: offset,
            part: part,
          );
          lostInARow = 0;
          received = answer.received;
          final placed = answer.file;
          if (placed != null) {
            _tell('$named is in ${to.name} now, as /porelo/files/$named.');
            return placed;
          }
          if (answer.received <= offset) {
            // The machine took nothing and placed nothing: asking again would loop.
            _tell(
              'The machine took none of the part at ${inWords(offset)} and placed nothing. '
              'Nothing more was sent.',
              failed: true,
            );
            return null;
          }
          offset = answer.received;
          notifyListeners();
        } on VarlinkException catch (refusal) {
          if (refusal.simpleName != 'PartOutOfOrder') rethrow;
          final at = _intIn(refusal, 'received');
          if (at == resumedAt) {
            _tell('The machine asked twice to go on at ${inWords(at)}. Nothing more was sent.', failed: true);
            return null;
          }
          resumedAt = at;
          offset = at;
          received = at;
          notifyListeners();
        } on VarlinkDisconnected {
          if (++lostInARow >= mostLostInARow) rethrow;
        }
      }
    } on VarlinkException catch (refusal) {
      _tell(wordsFor(refusal, to.name), failed: true);
    } on VarlinkDisconnected catch (ex) {
      _tell(
        'Lost contact with the machine $mostLostInARow times in a row: ${ex.message}. '
        '${inWords(received)} of ${inWords(size)} are there; handing it in again goes on '
        'from there for ten minutes.',
        failed: true,
      );
    } on FeatureNotSupported {
      _tell('This machine cannot hand a file to work.', failed: true);
    } on FileSystemException catch (ex) {
      // Read past the size it had, or taken away while it was read: what is there says so.
      _tell(
        '$named cannot be read here: ${ex.osError?.message ?? ex.message}. '
        '${inWords(received)} of ${inWords(size)} were sent.',
        failed: true,
      );
    } finally {
      await opened?.close();
    }
    return null;
  }

  /// Takes the file [named] out of [from] again.
  Future<HandedFile?> takeBack(FleetBackend backend, Task from, String named) async {
    task = from.name;
    name = named;
    busy = true;
    said = null;
    failed = false;
    notifyListeners();
    try {
      final file = await backend.takeBack(from.name, named);
      _tell('$named is out of ${from.name} again.');
      return file;
    } on VarlinkException catch (refusal) {
      _tell(wordsFor(refusal, from.name), failed: true);
    } on VarlinkDisconnected catch (ex) {
      _tell('Lost contact with the machine: ${ex.message}', failed: true);
    } on FeatureNotSupported {
      _tell('This machine cannot hand a file to work.', failed: true);
    }
    return null;
  }

  void _tell(String words, {bool failed = false}) {
    said = words;
    this.failed = failed;
    busy = false;
    notifyListeners();
  }

  /// A refusal of a hand-in or a take-back, in words that say what to do about it.
  static String wordsFor(VarlinkException refusal, String task) {
    String text(String key) => '${refusal.parameters[key] ?? ''}';
    return switch (refusal.simpleName) {
      'NotRunning' => '$task is not running any more, and a file goes only to running work.',
      'NoSuchTask' => '$task is not on this machine any more.',
      'FileTooLarge' =>
        'The file has ${inWords(_intIn(refusal, 'bytes'))}, and $task takes at '
            'most ${inWords(_intIn(refusal, 'limit'))}. A larger limit is set in the project file.',
      'FileNameRefused' =>
        'The machine will not take the name "${text('name')}": ${text('reason')}. '
            'Hand it in under another name.',
      'FileDiffers' =>
        'What arrived is not the file that was read, so nothing was placed. '
            'Hand it in again; if it changed while it was sent, wait until it is written.',
      'HandInInProgress' =>
        'Another file named "${text('name')}" is being handed in: '
            '${inWords(_intIn(refusal, 'received'))} of ${inWords(_intIn(refusal, 'bytes'))} are '
            'there. Wait for it, or hand this one in under another name.',
      'NoSuchFile' => '$task holds no handed-in file named "${text('name')}".',
      _ => 'Refused: ${refusal.simpleName}.',
    };
  }

  static int _intIn(VarlinkException refusal, String key) {
    final value = refusal.parameters[key];
    return value is num ? value.toInt() : 0;
  }

  /// A size as a person reads it.
  static String inWords(int bytes) {
    if (bytes == 1) return '1 byte';
    if (bytes < 1024) return '$bytes bytes';
    const units = ['KiB', 'MiB', 'GiB'];
    var size = bytes / 1024;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final shown = size >= 10 || size == size.roundToDouble() ? size.round().toString() : size.toStringAsFixed(1);
    return '$shown ${units[unit]}';
  }
}

/// The record of what one task's name has been handed, asked when somebody opens the task.
///
/// **Asked for one task, never while drawing a list**, like the work it holds: the record outlives
/// the task and is read from the machine's state, not from the listing.
class HandInRecord extends ChangeNotifier {
  /// Which task the answer belongs to, or null before anything was asked.
  String? task;

  /// What the machine said, oldest first. Null while unknown, or from a machine without hand-in.
  List<HandInEvent>? record;

  /// Why it could not be asked, in words.
  String? problem;

  int _asked = 0;

  /// Asks the record under [name].
  Future<void> look(FleetBackend backend, String name) async {
    final mine = ++_asked;
    task = name;
    record = null;
    problem = null;
    notifyListeners();
    try {
      final said = await backend.handIns(name);
      if (mine != _asked) return;
      record = said;
    } on VarlinkException catch (refusal) {
      if (mine != _asked) return;
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported {
      // A machine older than hand-in keeps no record; absent, never *nothing handed in*.
      if (mine != _asked) return;
      record = null;
    } finally {
      if (mine == _asked) notifyListeners();
    }
  }

  /// The record as lines for a person, newest last; empty when there is nothing to say.
  List<String> lines(String name) {
    if (task != name) return const [];
    if (problem != null) return [problem!];
    final said = record;
    if (said == null) return const [];
    if (said.isEmpty) return const ['nothing has been handed to work of this name'];
    final runs = said.map((each) => each.file.run).toSet();
    return [
      for (final each in said)
        '${each.file.name} ${each.event} by ${each.file.from}'
            '${each.file.at.isEmpty ? '' : ', ${each.file.at}'}'
            '${runs.length > 1 && each.file.run.isNotEmpty ? ' (run ${_short(each.file.run)})' : ''}',
    ];
  }

  static String _short(String run) => run.length > 12 ? run.substring(0, 12) : run;
}
