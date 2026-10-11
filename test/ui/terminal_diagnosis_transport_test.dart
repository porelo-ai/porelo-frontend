// Linux only: it stands a script in for `wsl.exe` on the PATH and opens a real pty.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/src/ui/terminal_diagnosis.dart';

/// The diagnosis reads back in the distribution exactly the bytes it sent, through a terminal as
/// the attach has one and through pipes as the relay has them: a raw terminal, so a carriage return
/// or an escape arrives as it was typed, and `od` ends by itself after as many bytes as were sent.
void main() {
  late Directory bin;
  setUp(() {
    bin = Directory.systemTemp.createTempSync('wsl-standin-');
    // `wsl.exe -d <distribution> --exec <program> <arguments>`, run here as the program itself.
    File('${bin.path}/wsl.exe')
      ..writeAsStringSync('#!/bin/sh\nshift 3\nexec "\$@"\n')
      ..createSync();
    Process.runSync('chmod', <String>['755', '${bin.path}/wsl.exe']);
  });
  tearDown(() => bin.deleteSync(recursive: true));

  for (final pseudoconsole in <bool>[true, false]) {
    test('through ${pseudoconsole ? 'a terminal' : 'pipes'}, a letter, a carriage return and an escape arrive as sent',
        () async {
      final read = await throughWslForReal('Ubuntu', <int>[0x61, 0x0d, 0x1b, 0x5b, 0x41],
          pseudoconsole: pseudoconsole, wslExe: '${bin.path}/wsl.exe');
      expect(read, contains(r'a  \r 033   [   A'));
    });
  }
}
