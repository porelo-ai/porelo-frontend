import 'dart:async';
import 'dart:io';

import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/desk.dart';

/// Every test runs as on Linux, wherever the suite runs: on GitHub's Windows runner a test must
/// never start `wsl.exe`, `icacls` or a pseudoconsole because the interface believed it was on
/// Windows. The Windows way is tested with a [Desk] of its own.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  desk = Desk.of('linux', Platform.environment);
  // A runner has no keepassxc-cli of its own: a test that is about it says so itself.
  keepassxcCliThere = () => true;
  keepassxcCliIsHere = true;
  await testMain();
}
