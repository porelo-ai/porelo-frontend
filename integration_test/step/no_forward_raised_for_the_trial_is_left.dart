import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Usage: no forward raised for the trial is left
///
/// Off the machine itself: no ssh process for the trial's socket, and no socket file.
Future<void> noForwardRaisedForTheTrialIsLeft(WidgetTester tester) async {
  final runtime = Platform.environment['XDG_RUNTIME_DIR']!;
  final files = Directory(runtime)
      .listSync()
      .where((each) => each.path.contains('trial'));
  expect(files, isEmpty, reason: 'the trial left its socket behind');
  final ssh = Process.runSync('pgrep', <String>[
    '-af',
    '$runtime/porelo-tunnel-[^ ]*trial',
  ]);
  expect(
    ssh.exitCode,
    isNot(0),
    reason: 'an ssh forward for the trial is still running: ${ssh.stdout}',
  );
}
