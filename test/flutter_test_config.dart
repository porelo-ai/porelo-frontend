import 'dart:async';
import 'dart:io';

import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/ui/host_vpn_dialog.dart';

/// Every test runs as on Linux, wherever the suite runs: on GitHub's Windows runner a test must
/// never start `wsl.exe`, `icacls` or a pseudoconsole because the interface believed it was on
/// Windows. The Windows way is tested with a [Desk] of its own.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  desk = Desk.of('linux', Platform.environment);
  // A runner has no keepassxc-cli of its own: a test that is about it says so itself.
  keepassxcCliThere = () => true;
  keepassxcCliIsHere = true;
  // The suite runs under the flutter snap's AppArmor label; a test that is about it gives its own.
  appArmorLabel = () => null;
  await testMain();
}
