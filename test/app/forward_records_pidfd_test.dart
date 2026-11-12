// Linux only: pidfds are Linux's.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forward_records.dart';

void main() {
  // Harm: on a C library older than glibc 2.36 (Ubuntu 22.04's), which has no pidfd_open, no leftover forward is ever
  // ended, and every start after a killed run is refused as a port or socket in use.
  test('a process is held and ended through the kernel call where the C library has none', () async {
    final process = await Process.start('sleep', <String>['300']);
    addTearDown(() => process.kill(ProcessSignal.sigkill));

    final pinned = const LinuxProcessTable(throughSyscall: true).pin(process.pid);

    expect(pinned, isNotNull, reason: 'the process is held through syscall');
    try {
      expect(pinned!.terminate(), isTrue);
    } finally {
      pinned?.release();
    }
    expect(await process.exitCode.timeout(const Duration(seconds: 5)), -ProcessSignal.sigterm.signalNumber);
  });
}
