import 'dart:async';
import 'dart:io';

import '../wire/limit_factors.dart';

/// Terminates an owned child, escalating when it ignores a graceful stop for [grace].
Future<void> stopOwnedProcess(Process process, {Duration grace = const Duration(seconds: 2)}) async {
  process.kill();
  try {
    await process.exitCode.timeout(machineWait(grace));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(machineWait(const Duration(seconds: 2)));
  }
}
