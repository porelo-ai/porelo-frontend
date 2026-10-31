import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Guards Windows, which has no mkdir -m: a private folder is made and kept to this user there as well.
  test('on Windows each folder made is restricted to the user before the next is made in it', () async {
    final scratch = await Directory.systemTemp.createTemp('private-directory-');
    addTearDown(() => scratch.delete(recursive: true));
    final restricted = <String>[];
    final writer = HostFileWriter(
      operatingSystem: 'windows',
      run: (executable, arguments) async {
        if (executable == 'whoami') return ProcessResult(0, 0, '"desk\\alice","S-1-5-21-1-2-3-1001"', '');
        restricted.add(arguments.first);
        return ProcessResult(0, 0, '', '');
      },
    );
    final made = Directory(path.join(scratch.path, 'filing', 'inner'));

    await privateDirectory(made, writer: writer);

    expect(made.existsSync(), isTrue);
    expect(restricted, [
      path.join(scratch.path, 'filing'),
      made.path,
      made.path,
    ], reason: 'each new folder is restricted, and the folder asked for once more');
  });
}
