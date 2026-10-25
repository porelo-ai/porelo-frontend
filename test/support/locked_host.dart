import 'dart:async';
import 'dart:io';

import 'package:porelo_host/src/steps.dart';

/// Holds a real process lock so tests exercise contention across process boundaries.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || !['hold', 'rent', 'play'].contains(arguments[0]) || !File(arguments[1]).isAbsolute) {
    throw const FormatException('Expected a phase and an absolute lock path');
  }
  final file = File(arguments[1]);
  await file.parent.create(recursive: true);
  final handle = await file.open(mode: FileMode.append);
  try {
    try {
      await handle.lock(FileLock.exclusive);
    } on FileSystemException {
      stdout.writeln(const Step('lock', StepState.refused).toLine());
      exitCode = 75;
      return;
    }
    if (arguments[0] == 'hold') {
      stdout.writeln('locked');
      await stdout.flush();
      await stdin.drain<void>();
    } else {
      final stopped = ProcessSignal.sigterm.watch().first;
      stdout.writeln(Step('rent', arguments[0] == 'rent' ? StepState.started : StepState.done).toLine());
      if (arguments[0] == 'play') stdout.writeln(const Step('play', StepState.started).toLine());
      await stdout.flush();
      await stopped;
    }
  } finally {
    await handle.close();
  }
}
