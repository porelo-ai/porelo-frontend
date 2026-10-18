// Linux only: it runs tool/e2e.sh in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/e2e.sh to the machine a lease names.
///
/// The harms: a lease file without the account's name ran the test as `@host`, which ssh fills with
/// whoever runs the build, against an account nobody leased; and a host key taken from whatever
/// answered at the address trusted a machine nobody made, where the lease names the one it made.
void main() {
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('e2e-lease-');
    final shims = Directory('${scratch.path}/bin')..createSync();
    for (final name in <String>['ssh-keyscan', 'xvfb-run']) {
      // The test's first program sees known_hosts as the run left it, before the cleanup forgets it.
      final seen = name == 'xvfb-run' ? 'cp "\$HOME/.ssh/known_hosts" "${scratch.path}/known_hosts.seen"\n' : '';
      final shim = File('${shims.path}/$name')
        ..writeAsStringSync('#!/bin/sh\necho "$name \$*" >> "${scratch.path}/ran"\n${seen}exit 0\n');
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

  const hostKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl';
  Map<String, String> aWholeLease() => <String, String>{
    'address': '192.0.2.7',
    'user': 'porelo',
    'socket': '/run/user/1000/porelo/porelod.sock',
    'hostkey': hostKey,
  };
  String written(Map<String, String> lease) => [for (final e in lease.entries) '${e.key}=${e.value}'].join('\n');

  for (final missing in <String>['user', 'socket', 'hostkey']) {
    test('a lease without its $missing stops the run before anything is asked of a machine', () async {
      final ran = await runWithTheLease(written(aWholeLease()..remove(missing)));

      expect(ran.exitCode, isNot(0));
      expect('${ran.stderr}', contains(missing));
      expect(File('${scratch.path}/ran').existsSync(), isFalse, reason: 'it went on to the machine');
    });
  }

  test('the machine is trusted by the host key its lease names, and nothing is asked of the address', () async {
    await runWithTheLease(written(aWholeLease()));

    expect(File('${scratch.path}/known_hosts.seen').readAsStringSync(), '192.0.2.7 $hostKey\n');
    expect(File('${scratch.path}/ran').readAsStringSync(), isNot(contains('ssh-keyscan')));
  });
}
