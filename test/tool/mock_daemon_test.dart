// Linux only: it starts the mock daemon on a unix socket, which dart:io cannot open on Windows.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/mock_daemon.dart`, run as a person runs it and stopped the way a person stops it.
void main() {
  late Directory scratch;

  setUp(() => scratch = Directory.systemTemp.createTempSync('porelo-mock-tool-test'));
  tearDown(() => scratch.deleteSync(recursive: true));

  test('ctrl-c stops it and takes its socket and directory with it', () async {
    final link = '${scratch.path}/mock.sock';
    final mock = await Process.start('dart', <String>['tool/mock_daemon.dart', 'work', link]);
    addTearDown(() => mock.kill(ProcessSignal.sigkill));
    final said = mock.stdout.transform(utf8.decoder).transform(const LineSplitter());
    // Its instructions come after the socket is up and the link to it is made.
    await said.firstWhere((line) => line.contains('stops')).timeout(const Duration(seconds: 60));
    final served = Link(link).targetSync();
    expect(FileSystemEntity.typeSync(served), FileSystemEntityType.unixDomainSock);

    mock.kill(ProcessSignal.sigint);

    expect(await mock.exitCode.timeout(const Duration(seconds: 20)), 0);
    expect(Link(link).existsSync(), isFalse, reason: 'the link at the stable name was left');
    expect(Directory(File(served).parent.path).existsSync(), isFalse, reason: "the daemon's directory was left");
  });

  test('a situation it does not know is a usage error', () async {
    final ran = await Process.run('dart', <String>[
      'tool/mock_daemon.dart',
      'no-such-situation',
      '${scratch.path}/m.sock',
    ]);

    expect(ran.exitCode, 64);
    expect('${ran.stderr}', contains('Unknown situation "no-such-situation"'));
  });
}
