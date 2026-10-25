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
        expect(
          (await Process.run('chmod', ['700', file.path])).exitCode,
          0,
          reason: 'the isolated tool must be executable',
        );
      }
      final capture = File('${scratch.path}/capture');
      final command = hostVpnUpCommand(source.path, commandPath: '${scratch.path}:/usr/bin:/bin');
      command[3] = command[3].replaceAll('/etc/', '${scratch.path}/etc/');
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
        expect(
          File('${source.path}.checked').readAsStringSync(),
          'expected-key\t100\t101\n',
          reason: 'the receipt must confirm the expected key and a handshake after the start',
        );
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

  for (final scenario in [
    (directory: false, nmcli: 'available', content: null),
    (directory: false, nmcli: 'missing', content: null),
    (directory: true, nmcli: 'available', content: null),
    (directory: true, nmcli: 'missing', content: null),
    (directory: true, nmcli: 'failing', content: null),
    (directory: true, nmcli: 'available', content: '[keyfile]\nunmanaged-devices=interface-name:another\n'),
    (directory: true, nmcli: 'available', content: '$_unmanagedRule\n'),
    (directory: true, nmcli: 'available', content: _unmanagedRule),
  ]) {
    final rule = switch (scenario.content) {
      null => 'absent',
      _unmanagedRule => 'exact',
      '$_unmanagedRule\n' => 'extra newline',
      _ => 'different',
    };
    // Harm: root script failures strand the VPN, repeated writes disrupt networking, and caller tools execute as root.
    test('VPN isolates NetworkManager with directory ${scenario.directory}, nmcli ${scenario.nmcli}, '
        'and rule $rule', () async {
      final scratch = Directory.systemTemp.createTempSync('vpn-network-manager-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final tools = Directory('${scratch.path}/tools')..createSync();
      final caller = Directory('${scratch.path}/caller')..createSync();
      final configuration = File('${scratch.path}/etc/NetworkManager/conf.d/porelo.conf');
      final previous = File('${scratch.path}/previous.conf');
      DateTime? previousModified;
      if (scenario.directory) configuration.parent.createSync(recursive: true);
      if (scenario.content != null) {
        configuration.writeAsStringSync(scenario.content!);
        final result = await Process.run('/usr/bin/chmod', ['644', configuration.path]);
        expect(result.exitCode, 0, reason: 'the existing configuration must start with its installed permissions');
        final linked = await Process.run('/usr/bin/ln', [configuration.path, previous.path]);
        expect(linked.exitCode, 0, reason: 'the previous inode must survive to detect in-place writes');
        configuration.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true));
        previousModified = configuration.lastModifiedSync();
      }
      final wireguard = File('${scratch.path}/etc/wireguard/porelo.conf');
      wireguard.parent.createSync(recursive: true);
      final source = File('${scratch.path}/source.conf')
        ..writeAsStringSync('[Peer]\nPublicKey = expected-key\nEndpoint = 203.0.113.7:51820\n');
      final capture = File('${scratch.path}/capture');
      final scripts = <String, String>{
        'date': "printf '100\\n'\n",
        'sleep': 'exit 0\n',
        'ping': 'exit 0\n',
        'wg': r'''case "$*" in
  'show interfaces') printf 'porelo\n';;
  'show porelo endpoints') printf 'expected-key\t203.0.113.7:51820\n';;
  'show porelo latest-handshakes') printf 'expected-key\t101\n';;
  *) exit 1;;
esac
''',
        'wg-quick': r'''printf '%s\n' "$1" >> "$VPN_CAPTURE"
''',
        'mv': r'''while [ "${1#-}" != "$1" ]; do shift; done
[ "${1%/*}" = "${2%/*}" ] || exit 1
exec /usr/bin/mv -- "$@"
''',
        if (scenario.nmcli != 'missing')
          'nmcli': r'''printf 'nmcli %s\n' "$*" >> "$VPN_CAPTURE"
[ "$VPN_NMCLI" != failing ]
''',
      };
      for (final entry in scripts.entries) {
        await _writeTool(tools, entry.key, entry.value);
      }
      await _writeTool(caller, 'nmcli', r'''printf 'caller nmcli\n' >> "$VPN_CAPTURE"
exit 1
''');
      for (final name in ['install', 'awk', 'cmp', 'mktemp', 'chmod', 'rm']) {
        Link('${tools.path}/$name').createSync('/usr/bin/$name');
      }
      final command = hostVpnUpCommand(source.path, commandPath: tools.path);
      command[3] = command[3].replaceAll('/etc/', '${scratch.path}/etc/');
      Future<void> run() async {
        final result = await Process.run(
          '/bin/sh',
          command.skip(2).toList(),
          environment: {'PATH': caller.path, 'VPN_CAPTURE': capture.path, 'VPN_NMCLI': scenario.nmcli},
          includeParentEnvironment: false,
        );
        expect(result.exitCode, 0, reason: 'optional NetworkManager support must not prevent the VPN from coming up');
        expect(wireguard.existsSync(), isTrue, reason: 'the root script must still install the tunnel');
        expect(File('${source.path}.checked').existsSync(), isTrue, reason: 'the tunnel must pass its handshake check');
      }

      await run();
      final reload = scenario.directory && scenario.nmcli != 'missing' && scenario.content != _unmanagedRule;
      final firstActions = [if (reload) 'nmcli general reload conf', 'down', 'up'];
      expect(
        capture.readAsLinesSync(),
        firstActions,
        reason: 'only changed rules reload, before tunnel renewal, using trusted tools',
      );
      if (scenario.content != null) {
        expect(
          previous.readAsStringSync(),
          scenario.content,
          reason: 'publication must not overwrite the previous inode',
        );
        expect(
          FileSystemEntity.identicalSync(configuration.path, previous.path),
          scenario.content == _unmanagedRule,
          reason: 'only differing configuration must be replaced by a staged file',
        );
        if (scenario.content == _unmanagedRule) {
          expect(
            configuration.lastModifiedSync(),
            previousModified,
            reason: 'an already exact rule must not be rewritten',
          );
        }
      }
      DateTime? modified;
      File? original;
      if (scenario.directory) {
        expect(configuration.existsSync(), isTrue, reason: 'NetworkManager must leave the tunnel to WireGuard');
        expect(configuration.readAsStringSync(), _unmanagedRule, reason: 'only the porelo interface must be unmanaged');
        expect(
          configuration.statSync().mode & 0x1ff,
          0x1a4,
          reason: 'NetworkManager configuration must have mode 0644',
        );
        original = File('${scratch.path}/original.conf');
        final linked = await Process.run('/usr/bin/ln', [configuration.path, original.path]);
        expect(linked.exitCode, 0, reason: 'a hard link must retain the original inode to detect a replacement');
        configuration.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true));
        modified = configuration.lastModifiedSync();
      } else {
        expect(
          Directory('${scratch.path}/etc/NetworkManager').existsSync(),
          isFalse,
          reason: 'systems without NetworkManager must not gain configuration',
        );
      }
      await run();
      expect(capture.readAsLinesSync(), [
        ...firstActions,
        'down',
        'up',
      ], reason: 'an unchanged rule must never reload NetworkManager');
      if (scenario.directory) {
        expect(
          FileSystemEntity.identicalSync(configuration.path, original!.path),
          isTrue,
          reason: 'an unchanged rule must not be replaced',
        );
        expect(configuration.lastModifiedSync(), modified, reason: 'an unchanged rule must not be rewritten in place');
        expect(configuration.parent.listSync().map((entry) => entry.path), [
          configuration.path,
        ], reason: 'publication must leave no temporary files');
      } else {
        expect(
          configuration.parent.existsSync(),
          isFalse,
          reason: 'a second run must still leave NetworkManager absent',
        );
      }
    });
  }

  // Harm: a missing root tool escapes the refusal as a file error, so the VPN step fails without naming what it needs.
  test('a missing wg is refused before any root command is opened', () async {
    final scratch = Directory.systemTemp.createTempSync('vpn-tools-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    for (final name in ['sudo', 'sh', 'wg-quick', 'ping', 'install', 'date', 'sleep', 'awk']) {
      final file = File('${scratch.path}/$name')..writeAsStringSync('#!/bin/sh\nexit 0\n');
      expect(
        (await Process.run('chmod', ['700', file.path])).exitCode,
        0,
        reason: 'the tool must be executable so only missing wg causes refusal',
      );
    }
    await expectLater(
      checkHostVpnRootTools(directories: [scratch.path]),
      throwsA(isA<HostFilesRefused>()),
      reason: 'wg is in none of the searched directories',
    );
  });
}

const _unmanagedRule = '[keyfile]\nunmanaged-devices=interface-name:porelo\n';

Future<void> _writeTool(Directory directory, String name, String script) async {
  final file = File('${directory.path}/$name')..writeAsStringSync('#!/bin/sh\n$script');
  final result = await Process.run('/usr/bin/chmod', ['700', file.path]);
  expect(result.exitCode, 0, reason: 'the isolated tool must be executable');
}
