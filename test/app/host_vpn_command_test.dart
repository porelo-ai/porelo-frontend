@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  for (final scenario in [
    'missing handshake',
    'wrong key',
    'old handshake',
    'other host',
    'ping failure',
    'install failure',
    'up failure',
    'wg failure',
    'success',
    'same host',
    'down failure',
  ]) {
    // Harm: false readiness or replacing another host tunnel sends work over an unverified VPN;
    // reusing a running tunnel to the same server fails its handshake check and never installs a changed configuration.
    test('VPN checks $scenario before reporting success', () async {
      final scratch = Directory.systemTemp.createTempSync('vpn-guard-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final folder = Directory('${scratch.path}/private folder')..createSync();
      final source = File('${folder.path}/porelo.conf')
        ..writeAsStringSync(
          '[Interface]\nPrivateKey = invented-private-key\n[Peer]\nPublicKey = expected-key\nEndpoint = 203.0.113.7:51820\n',
        );
      final scripts = <String, String>{
        'sudo': r'''exec "$@"
''',
        'install': r'''printf 'install\n' >> "$VPN_CAPTURE"
[ "$VPN_SCENARIO" != 'install failure' ]
''',
        'wg-quick': r'''printf '%s\n' "$1" >> "$VPN_CAPTURE"
[ "$VPN_SCENARIO $1" != 'up failure up' ] && [ "$VPN_SCENARIO $1" != 'down failure down' ]
''',
        'ping': r'''[ "$VPN_SCENARIO" != 'ping failure' ]
''',
        'date': "printf '100\\n'\n",
        'sleep': 'exit 0\n',
        'wg': r'''case "$*" in
  'show interfaces')
    [ "$VPN_SCENARIO" != 'wg failure' ] || exit 1
    case "$VPN_SCENARIO" in 'other host'|'same host'|'down failure') printf 'porelo\n';; esac;;
  'show porelo endpoints')
    if [ "$VPN_SCENARIO" = 'same host' ] || [ "$VPN_SCENARIO" = 'down failure' ]; then printf 'expected-key\t203.0.113.7:51820\n';
    else printf 'another-key\t203.0.113.8:51820\n'; fi;;
  'show porelo latest-handshakes')
    case "$VPN_SCENARIO" in
      'missing handshake') printf 'expected-key\t0\n';;
      'wrong key') printf 'wrong-key\t101\n';;
      'old handshake') printf 'expected-key\t99\n';;
      *) printf 'expected-key\t101\n';;
    esac;;
  *) exit 1;;
esac
''',
      };
      for (final entry in scripts.entries) {
        final file = File('${scratch.path}/${entry.key}')..writeAsStringSync('#!/bin/sh\n${entry.value}');
        expect((await Process.run('chmod', ['700', file.path])).exitCode, 0);
      }
      final capture = File('${scratch.path}/capture');
      final command = hostVpnUpCommand(source.path, commandPath: '${scratch.path}:/usr/bin:/bin');
      final result = await Process.run(
        command.first,
        command.skip(1).toList(),
        environment: {'PATH': '${scratch.path}:/usr/bin:/bin', 'VPN_SCENARIO': scenario, 'VPN_CAPTURE': capture.path},
      );
      final success = scenario == 'success' || scenario == 'same host';
      expect(result.exitCode == 0, success, reason: '$scenario must produce only a verified success');
      if (success) {
        expect(
          File('${source.path}.checked').existsSync(),
          isTrue,
          reason: 'verified success must leave its public receipt',
        );
        expect(File('${source.path}.checked').readAsStringSync(), 'expected-key\t100\t101\n');
        expect(
          capture.readAsLinesSync(),
          scenario == 'same host' ? ['down', 'install', 'up'] : ['install', 'up'],
          reason: 'a running tunnel to the same server is taken down, then installed and brought up afresh',
        );
      }
      if (scenario == 'other host') {
        expect(capture.existsSync(), isFalse, reason: 'an active tunnel must be checked before install or up');
      }
      if (scenario == 'down failure') {
        expect(capture.readAsLinesSync(), ['down'], reason: 'nothing is installed over a tunnel that did not go down');
      }
      expect(
        File('${source.path}.checked').existsSync(),
        success,
        reason: 'only a fresh expected handshake produces a receipt',
      );
    });
  }

  // Harm: a missing root tool escapes the refusal as a file error, so the VPN step fails without naming what it needs.
  test('a missing wg is refused before any root command is opened', () async {
    final scratch = Directory.systemTemp.createTempSync('vpn-tools-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    for (final name in ['sudo', 'sh', 'wg-quick', 'ping', 'install', 'date', 'sleep', 'awk']) {
      final file = File('${scratch.path}/$name')..writeAsStringSync('#!/bin/sh\nexit 0\n');
      expect((await Process.run('chmod', ['700', file.path])).exitCode, 0);
    }
    await expectLater(
      checkHostVpnRootTools(directories: [scratch.path]),
      throwsA(isA<HostFilesRefused>()),
      reason: 'wg is in none of the searched directories',
    );
  });
}
