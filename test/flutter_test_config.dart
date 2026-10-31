import 'dart:async';
import 'dart:io';

import 'package:porelo_frontend/src/app/desk.dart';

/// Every test runs as on Linux, wherever the suite runs: on GitHub's Windows runner a test must
/// never start `wsl.exe`, `icacls` or a pseudoconsole because the interface believed it was on
/// Windows. The Windows way is tested with a [Desk] of its own. Windows has no `HOME`, so the Linux desk is given
/// one of its own there, as every Linux account has.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  desk = Desk.of('linux', {
    ...Platform.environment,
    if (Platform.environment['HOME'] == null) 'HOME': '/home/porelo-test',
  });
  await testMain();
}
