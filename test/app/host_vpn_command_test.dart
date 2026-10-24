@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';

void main() {
  for (final installExit in [0, 1]) {
    // Harm: shell splitting or ignoring install failure can configure the wrong VPN as root.
    test('the shell passes one source argument and starts WireGuard only after install exit $installExit', () async {
      final scratch = Directory.systemTemp.createTempSync('vpn-command-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final capture = File('${scratch.path}/arguments');
      final sudo = File('${scratch.path}/sudo')
        ..writeAsStringSync(
          '#!/bin/sh\n'
          r'''printf '%s\000' "$@" >> "$VPN_CAPTURE"
if [ "$1" = install ]; then exit "$VPN_INSTALL_EXIT"; fi
''',
        );
      final mode = await Process.run('chmod', ['700', sudo.path]);
      expect(mode.exitCode, 0, reason: 'the stand-in must be executable before testing the shell');
      const source = '/tmp/private folder/porelo.conf';
      final command = hostVpnUpCommand(source);
      final result = await Process.run(
        command.first,
        command.skip(1).toList(),
        environment: {'PATH': scratch.path, 'VPN_CAPTURE': capture.path, 'VPN_INSTALL_EXIT': '$installExit'},
      );
      expect(result.exitCode, installExit);
      expect(capture.readAsStringSync().split('\x00')..removeLast(), [
        'install',
        '-m',
        '600',
        source,
        '/etc/wireguard/porelo.conf',
        if (installExit == 0) ...['wg-quick', 'up', 'porelo'],
      ], reason: 'sudo must receive the entire source path once, and up must depend on install');
    });
  }
}
