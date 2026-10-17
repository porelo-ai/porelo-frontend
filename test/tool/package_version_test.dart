// Linux only: it runs tool/package.sh in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/package.sh to letting a release through its version checks.
///
/// The checks that a snapshot sorts below the release and below the next build are about
/// snapshots; a release is the version itself and must not be compared with itself.
void main() {
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('package-version-');
    // Stands in for the build: says it was reached, and stops the script there.
    final flutter = File('${scratch.path}/flutter')
      ..writeAsStringSync('#!/bin/sh\necho "the build was reached"\nexit 9\n');
    Process.runSync('chmod', <String>['755', flutter.path]);
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  Future<ProcessResult> package({required bool release}) => Process.run(
    'bash',
    <String>['tool/package.sh', '0.4.0'],
    environment: <String, String>{
      'PATH': '${scratch.path}:${Platform.environment['PATH']}',
      'NFPM': '/bin/true',
      'OUT_DIR': '${scratch.path}/out',
      'SNAPSHOT_RUN': '126',
      // Always said, never inherited: a tag's build runs the suite with RELEASE=1 set.
      'RELEASE': release ? '1' : '0',
    },
  );

  test('a release passes the version checks and reaches the build', () async {
    final result = await package(release: true);
    final said = '${result.stdout}${result.stderr}';
    expect(
      said,
      contains('Checking the version supersedes the last one: 0.4.0\n'),
      reason: 'a release is packaged as its own version:\n$said',
    );
    expect(said, contains('the build was reached'), reason: 'the release stopped before the build:\n$said');
  });

  test('a snapshot still passes the version checks as before', () async {
    final result = await package(release: false);
    final said = '${result.stdout}${result.stderr}';
    expect(said, contains('Checking the version supersedes the last one: 0.4.0~snapshot.126'));
    expect(said, contains('the build was reached'), reason: 'the snapshot stopped before the build:\n$said');
  });
}
