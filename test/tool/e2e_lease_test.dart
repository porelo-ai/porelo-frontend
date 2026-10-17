// Linux only: it runs tool/e2e.sh in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/e2e.sh to the machine a lease names.
///
/// The harm: a lease file without the account's name ran the test as `@host`, which ssh fills with
/// whoever runs the build, against an account nobody leased.
void main() {
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('e2e-lease-');
    final shims = Directory('${scratch.path}/bin')..createSync();
    for (final name in <String>['ssh-keyscan', 'xvfb-run']) {
      final shim = File('${shims.path}/$name')
        ..writeAsStringSync('#!/bin/sh\necho "$name \$*" >> "${scratch.path}/ran"\nexit 0\n');
      Process.runSync('chmod', <String>['755', shim.path]);
    }
    File('${scratch.path}/e2e.sh').writeAsBytesSync(File('tool/e2e.sh').readAsBytesSync());
    Directory('${scratch.path}/build').createSync();
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  Future<ProcessResult> runWithTheLease(String lease) {
    File('${scratch.path}/build/leased.properties').writeAsStringSync(lease);
    return Process.run(
      'bash',
      <String>['e2e.sh'],
      workingDirectory: scratch.path,
      environment: <String, String>{
        'PATH': '${scratch.path}/bin:${Platform.environment['PATH']}',
        'HOME': scratch.path,
      },
      includeParentEnvironment: false,
    );
  }

  for (final missing in <String>['user', 'socket']) {
    test('a lease without its $missing stops the run before anything is asked of a machine', () async {
      final lease = <String, String>{
        'address': '192.0.2.7',
        'user': 'porelo',
        'socket': '/run/user/1000/porelo/porelod.sock',
      }..remove(missing);
      final ran = await runWithTheLease([for (final e in lease.entries) '${e.key}=${e.value}'].join('\n'));

      expect(ran.exitCode, isNot(0));
      expect('${ran.stderr}', contains(missing));
      expect(File('${scratch.path}/ran').existsSync(), isFalse, reason: 'it went on to the machine');
    });
  }
}
