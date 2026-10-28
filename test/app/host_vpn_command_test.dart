@Tags(<String>['linux'])
library;

import 'dart:convert';
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

  // Harm: the forge's name left pointing at a link that is down, a line of the person's own taken with it, or
  // /etc/hosts replaced by another file.
  for (final downs in [true, false]) {
    test('taking the VPN down takes the forge\'s name out of /etc/hosts, and nothing else (down $downs)', () async {
      final scratch = Directory.systemTemp.createTempSync('vpn-down-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final hosts = File('${scratch.path}/hosts')
        ..writeAsStringSync(
          '127.0.0.1 localhost\n10.73.0.1 forge.porelo.internal # porelo-host\n10.0.0.5 mine # porelo-host\n',
        );
      final inode = (await Process.run('stat', ['-c', '%i', hosts.path])).stdout;
      final wg = File('${scratch.path}/wg-quick')..writeAsStringSync('#!/bin/sh\n${downs ? 'exit 0' : 'exit 1'}\n');
      await Process.run('chmod', ['700', wg.path]);
      final script = hostVpnDownCommand[3]
          .replaceAll('/etc/hosts', hosts.path)
          .replaceAll('PATH=/usr/bin:/usr/sbin:/bin:/sbin', 'PATH=${scratch.path}:/usr/bin:/bin');
      final result = await Process.run('/bin/sh', ['-c', script]);
      expect(result.exitCode == 0, downs, reason: '${result.stderr}');
      expect(
        hosts.readAsStringSync(),
        downs
            ? '127.0.0.1 localhost\n10.0.0.5 mine # porelo-host\n'
            : '127.0.0.1 localhost\n10.73.0.1 forge.porelo.internal # porelo-host\n10.0.0.5 mine # porelo-host\n',
        reason: 'that one line, never another that only ends like it',
      );
      expect(
        (await Process.run('stat', ['-c', '%i', hosts.path])).stdout,
        inode,
        reason: 'the same file, written into',
      );
    });
  }

  // Harm: the forge's CA put where nothing reads it, written again on every VPN start, a policy of Firefox's own
  // replaced, the forge's name added twice or glued to the person's last line, root copying a file the person could
  // swap, or anything of it done without a CA a stop gave.
  group('the forge\'s CA and name', () {
    late Directory scratch;
    late Directory etc;
    late File hosts;
    late File capture;
    late File source;
    final ca =
        '-----BEGIN CERTIFICATE-----\n${base64.encode(List<int>.generate(48, (i) => i))}\n-----END CERTIFICATE-----\n';

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('vpn-forge-');
      final folder = Directory('${scratch.path}/private')..createSync();
      source = File('${folder.path}/porelo.conf')
        ..writeAsStringSync(
          '[Interface]\nPrivateKey = invented-private-key\n[Peer]\nPublicKey = expected-key\nEndpoint = 203.0.113.7:51820\n',
        );
      etc = Directory('${scratch.path}/etc')..createSync();
      Directory('${etc.path}/wireguard').createSync();
      hosts = File('${etc.path}/hosts')..writeAsStringSync('127.0.0.1 localhost\n');
      capture = File('${scratch.path}/capture');
    });
    tearDown(() => scratch.deleteSync(recursive: true));

    Future<ProcessResult> up({
      String? forgeCa,
      String store = 'update-ca-certificates',
      bool storeTakes = true,
      String? argument,
    }) async {
      final tools = <String, String>{
        'sudo': r'exec "$@"',
        'wg-quick': 'exit 0',
        'ping': 'exit 0',
        'date': "printf '100\\n'",
        'sleep': 'exit 0',
        store: '''printf '%s\\n' '$store' >> "\$VPN_CAPTURE"\n${storeTakes ? 'exit 0' : 'exit 1'}''',
        'wg': r'''case "$*" in
  'show interfaces') ;;
  'show porelo latest-handshakes') printf 'expected-key\t101\n';;
  *) exit 1;;
esac''',
      };
      for (final entry in tools.entries) {
        final file = File('${scratch.path}/${entry.key}')..writeAsStringSync('#!/bin/sh\n${entry.value}\n');
        await Process.run('chmod', ['700', file.path]);
      }
      final command = hostVpnUpCommand(source.path, commandPath: '${scratch.path}:/usr/bin:/bin', forgeCa: forgeCa);
      command[3] = command[3]
          .replaceAll('/etc/', '${etc.path}/')
          .replaceAll('/usr/local/share/', '${scratch.path}/usr/local/share/');
      if (argument != null) command[command.length - 1] = argument;
      return Process.run(
        command.first,
        command.skip(1).toList(),
        environment: {'PATH': '${scratch.path}:/usr/bin:/bin', 'VPN_CAPTURE': capture.path},
      );
    }

    File inStore() => File('${scratch.path}/usr/local/share/ca-certificates/porelo-host.crt');
    File forFirefox() => File('${etc.path}/firefox/porelo/porelo-host.crt');
    File policy() => File('${etc.path}/firefox/policies/policies.json');

    test('nothing of it without a CA a stop gave', () async {
      final none = await up();
      expect(none.exitCode, 0, reason: '${none.stdout}${none.stderr}');
      expect(Directory('${etc.path}/firefox').existsSync(), isFalse);
      expect(hosts.readAsStringSync(), '127.0.0.1 localhost\n');
    });

    test('put in place once, the policy naming the copy a snap reads, the name on a line of its own', () async {
      hosts.writeAsStringSync('127.0.0.1 localhost\n192.168.1.50 nas.local');
      final first = await up(forgeCa: ca);
      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      expect(inStore().readAsStringSync(), ca);
      expect(forFirefox().readAsStringSync(), ca);
      // The test moved /etc into its scratch folder, the policy's path with it.
      expect(policy().readAsStringSync(), contains('"Install":["${etc.path}/firefox/porelo/porelo-host.crt"]'));
      expect(capture.readAsLinesSync(), ['update-ca-certificates'], reason: 'the system store is told once');
      expect(
        hosts.readAsStringSync(),
        '127.0.0.1 localhost\n192.168.1.50 nas.local\n10.73.0.1 forge.porelo.internal # porelo-host\n',
        reason: 'the person\'s last line stays as it was',
      );
      expect(File('${source.path}.checked').existsSync(), isTrue);

      final copied = forFirefox().statSync().modified;
      final again = await up(forgeCa: ca);
      expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
      expect(capture.readAsLinesSync(), ['update-ca-certificates'], reason: 'the same CA is not put in again');
      expect(forFirefox().statSync().modified, copied, reason: 'nor Firefox\'s copy');
      expect('forge.porelo.internal'.allMatches(hosts.readAsStringSync()), hasLength(1), reason: 'the name once');
      expect('${again.stdout}', isNot(contains('policy of its own')));
    });

    test('a policy of Firefox\'s own, or a link in its place, is said and never replaced', () async {
      Directory('${etc.path}/firefox/policies').createSync(recursive: true);
      policy().writeAsStringSync('{"policies":{"DisableTelemetry":true}}\n');
      final own = await up(forgeCa: ca);
      expect(own.exitCode, 0);
      expect(policy().readAsStringSync(), '{"policies":{"DisableTelemetry":true}}\n');
      expect('${own.stdout}', contains('Firefox has a policy of its own'));

      policy().deleteSync();
      Link(policy().path).createSync('${scratch.path}/not-mounted/policies.json');
      final linked = await up(forgeCa: ca);
      expect(linked.exitCode, 0);
      expect(FileSystemEntity.isLinkSync(policy().path), isTrue, reason: 'a dangling link is the person\'s too');
    });

    test('Fedora\'s store, a store that does not take it, and no store at all', () async {
      final fedora = await up(forgeCa: ca, store: 'update-ca-trust');
      expect(fedora.exitCode, 0, reason: '${fedora.stdout}${fedora.stderr}');
      expect(File('${etc.path}/pki/ca-trust/source/anchors/porelo-host.crt').readAsStringSync(), ca);
      expect(capture.readAsLinesSync(), ['update-ca-trust']);
    });

    test('a store that does not take it is tried again, and no store at all is said', () async {
      final refused = await up(forgeCa: ca, storeTakes: false);
      expect(refused.exitCode, isNot(0));
      expect(inStore().existsSync(), isFalse, reason: 'taken back, so the next start tries again');
      expect(File('${source.path}.checked').existsSync(), isFalse, reason: 'no receipt where it failed');
      final retried = await up(forgeCa: ca);
      expect(retried.exitCode, 0, reason: '${retried.stdout}${retried.stderr}');
      expect(capture.readAsLinesSync(), ['update-ca-certificates', 'update-ca-certificates']);
    });

    test('what is not one certificate is refused, here and by root', () async {
      for (final bad in [
        '-----BEGIN CERTIFICATE-----\nAAAA-----END CERTIFICATE-----\n',
        '-----BEGIN CERTIFICATE-----\n\n-----END CERTIFICATE-----\n',
        '$ca$ca',
        "-----BEGIN CERTIFICATE-----\nAAAA'\n-----END CERTIFICATE-----\n",
      ]) {
        expect(isForgeCaCertificate(bad), isFalse, reason: bad);
        expect(() => hostVpnUpCommand(source.path, forgeCa: bad), throwsFormatException);
      }
      // Root's own check, should something else reach it: nothing installed, no receipt.
      final reached = await up(forgeCa: ca, argument: '$ca${ca}extra');
      expect(reached.exitCode, isNot(0));
      expect('${reached.stdout}', contains('not one certificate'));
      expect(inStore().existsSync(), isFalse);
      expect(forFirefox().existsSync(), isFalse);
    });
  });

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
