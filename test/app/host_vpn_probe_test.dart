import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_process.dart';

void main() {
  for (final code in [0, 1, 2]) {
    // Harm: reading state through sudo prompts for root unnecessarily, and a guessed link routes the wrong root action.
    test('the unprivileged link probe handles exit $code without another command', () async {
      final commands = <List<String>>[];
      final process = HostProcess();
      final probe = probeHostVpnLink(
        start: (executable, arguments) async {
          commands.add([executable, ...arguments]);
          return process;
        },
      );
      process.end(code);
      if (code == 2) {
        await expectLater(probe, throwsA(isA<HostFilesRefused>()), reason: 'an unexpected ip failure is not absence');
      } else {
        expect(await probe, code == 0, reason: 'only exit zero means that the local interface exists');
      }
      expect(commands, [
        ['ip', 'link', 'show', 'dev', 'porelo'],
      ], reason: 'state must be read without root, a shell, or a second process');
    });
  }

  // Harm: a missing state probe must not become permission for a root action or expose raw process diagnostics.
  test('a missing link probe reports a safe refusal', () async {
    Object? refusal;
    try {
      await probeHostVpnLink(start: (_, _) async => throw const ProcessException('ip', [], 'untrusted diagnostic'));
    } catch (error) {
      refusal = error;
    }
    expect(refusal, isA<HostFilesRefused>(), reason: 'a failed check must be refused explicitly');
    expect('$refusal', isNot(contains('untrusted diagnostic')), reason: 'process details must not reach the refusal');
  });

  // Harm: a hung link check blocks the VPN action indefinitely or leaves its subprocess running.
  testWidgets('a stuck link probe is killed and refused at its deadline', (tester) async {
    final process = _StuckProbe();
    final probe = probeHostVpnLink(start: (_, _) async => process);
    final refused = expectLater(
      probe,
      throwsA(isA<HostFilesRefused>()),
      reason: 'a timed-out check cannot authorize sudo',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(process.killed, isTrue, reason: 'a timed-out subprocess must not remain running');
    await refused;
  });
}

class _StuckProbe extends HostProcess {
  bool killed = false;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    end(-15);
    return true;
  }
}
