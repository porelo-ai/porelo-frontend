import 'dart:async';
import 'dart:io';

/// Terminates an owned child, escalating when it ignores a graceful stop.
Future<void> stopOwnedProcess(Process process) async {
  process.kill();
  try {
    await process.exitCode.timeout(const Duration(seconds: 2));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 2));
  }
}
