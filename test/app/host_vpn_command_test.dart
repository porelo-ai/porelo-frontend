@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: a nonzero host network exported as network zero routes traffic to another host.
  test('a private VPN attempt uses the recorded host network', () async {
    final runtime = Directory.systemTemp.createTempSync('vpn-runtime-');
    addTearDown(() => runtime.deleteSync(recursive: true));
    expect((await Process.run('/usr/bin/chmod', ['700', runtime.path])).exitCode, 0);
    final store = _VpnSecrets();
    final key = await HostFiles.publicKey(store.privateKey);
    final attempt = await prepareHostVpn(
      project: 'second',
      tunnel: HostTunnel(hostPublicKey: key, peerPublicKey: key),
      address: '203.0.113.8',
      secretStore: store,
      environment: {'XDG_RUNTIME_DIR': runtime.path},
      checkRootTools: () async {},
      networkNumber: 17,
    );
    addTearDown(attempt.close);
    final configuration = await attempt.file.readAsString();
    expect(configuration, contains('Address = 10.73.17.2/24'));
    expect(configuration, contains('AllowedIPs = 10.73.17.1/32'));
    expect(configuration, isNot(contains('10.73.0.')));
  });

  // Harm: the presence of another host's link must not authorize taking it down.
  test('link probes distinguish the owner and keep legacy links readable', () async {
    for (final (interface, alias, expected) in [
      ('porelo-0', 'porelo-host-first', true),
      ('porelo-0', 'porelo-host-second', false),
      ('porelo', '', true),
    ]) {
      final commands = <List<String>>[];
      final result = await probeHostVpnLink(
        interface: interface,
        host: 'first',
        start: (executable, arguments) async {
          commands.add([executable, ...arguments]);
          final output = jsonEncode([
            {'ifname': interface, if (alias.isNotEmpty) 'ifalias': alias},
          ]);
          return Process.start('/bin/sh', ['-c', "printf '%s' '$output'"]);
        },
      );
      expect(result, expected);
      expect(commands, [
        ['ip', '-j', 'link', 'show', 'dev', interface],
      ]);
    }
  });

  // Harm: a colliding network routes work to another host before sudo can safely change anything.
  test('an active network collision names both hosts before root is opened', () async {
    for (final active in ['porelo-17', 'porelo']) {
      final commands = <List<String>>[];
      await expectLater(
        checkHostVpnNetwork(
          host: 'second',
          networkNumber: 17,
          hostsByInterface: {active: 'first'},
          run: (executable, arguments) async {
            commands.add([executable, ...arguments]);
            return ProcessResult(
              1,
              0,
              executable == 'wg'
                  ? active
                  : jsonEncode(
                      arguments.contains('link')
                          ? [
                              {'ifname': active, 'ifalias': 'porelo-host-first'},
                            ]
                          : [
                              {'dst': '10.73.17.0/24', 'dev': active},
                            ],
                    ),
              '',
            );
          },
        ),
        throwsA(
          isA<HostFilesRefused>().having(
            (error) => error.message,
            'both hosts',
            allOf(contains('first'), contains('second')),
          ),
        ),
      );
      expect(commands.map((command) => command.first), ['wg', 'ip', 'ip']);
    }
  });

  // Harm: a refused second host leaves a saved record that must not claim the first host's live interface.
  test('the active link owner wins over a dormant colliding record', () async {
    await checkHostVpnNetwork(
      host: 'first',
      networkNumber: 17,
      hostsByInterface: {'porelo-17': 'second'},
      run: (executable, arguments) async => ProcessResult(
        1,
        0,
        executable == 'wg'
            ? 'porelo-17'
            : jsonEncode(
                arguments.contains('link')
                    ? [
                        {'ifname': 'porelo-17', 'ifalias': 'porelo-host-first'},
                      ]
                    : [
                        {'dst': '10.73.17.1', 'dev': 'porelo-17'},
                      ],
              ),
        '',
      ),
    );
  });

  // Harm: malformed ownership metadata must not fall back to a saved record and authorize root.
  test('a malformed active owner is refused instead of guessed from settings', () async {
    await expectLater(
      checkHostVpnNetwork(
        host: 'first',
        networkNumber: 17,
        hostsByInterface: {'porelo-17': 'first'},
        run: (executable, arguments) async => ProcessResult(
          1,
          0,
          executable == 'wg'
              ? 'porelo-17'
              : jsonEncode(
                  arguments.contains('link')
                      ? [
                          {'ifname': 'porelo-17', 'ifalias': 17},
                        ]
                      : [
                          {'dst': '10.73.17.1', 'dev': 'porelo-17'},
                        ],
                ),
          '',
        ),
      ),
      throwsA(isA<HostFilesRefused>()),
    );
  });

  // Harm: a failed network inspection cannot authorize changes to routes.
  test('unreadable routes and unknown owners fail closed', () async {
    for (final routes in ['invalid', '[{"dst":"10.73.17.1","dev":"porelo-9"}]']) {
      await expectLater(
        checkHostVpnNetwork(
          host: 'second',
          networkNumber: 17,
          run: (executable, _) async => ProcessResult(1, 0, executable == 'wg' ? 'porelo-9' : routes, ''),
        ),
        throwsA(isA<HostFilesRefused>()),
      );
    }
  });

  // Harm: accepting shell syntax or mismatched interface numbers changes unrelated root files.
  test('VPN commands refuse invalid host network and interface arguments', () {
    for (final interface in ['porelo-256', 'porelo-017', 'other', 'porelo-17;id', 'porelo-0']) {
      expect(() => hostVpnDownCommand(host: 'demo', networkNumber: 17, interface: interface), throwsFormatException);
    }
  });

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
        'ip': 'exit 0\n',
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
    case "$VPN_SCENARIO" in 'other host'|'same host'|'down failure') printf 'porelo-0\n';; esac;;
  'show porelo-0 endpoints')
    if [ "$VPN_SCENARIO" = 'same host' ] || [ "$VPN_SCENARIO" = 'down failure' ]; then printf 'expected-key\t203.0.113.7:51820\n';
    else printf 'another-key\t203.0.113.8:51820\n'; fi;;
  'show porelo-0 latest-handshakes'|'show porelo-17 latest-handshakes')
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
      final command = hostVpnUpCommand(source.path, host: 'demo', commandPath: '${scratch.path}:/usr/bin:/bin');
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
  for (final (downs, copies) in [(true, true), (false, true), (true, false)]) {
    test('taking the VPN down takes the forge\'s name out of /etc/hosts, and nothing else '
        '(down $downs, copy written $copies)', () async {
      final scratch = Directory.systemTemp.createTempSync('vpn-down-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final hosts = File('${scratch.path}/hosts')
        ..writeAsStringSync(
          '127.0.0.1 localhost\n10.73.0.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo\n10.0.0.5 mine # porelo-host\n',
        );
      final inode = (await Process.run('stat', ['-c', '%i', hosts.path])).stdout;
      final wg = File('${scratch.path}/wg-quick')
        ..writeAsStringSync('#!/bin/sh\n[ "\$*" = "down porelo" ] || exit 3\n${downs ? 'exit 0' : 'exit 1'}\n');
      await Process.run('chmod', ['700', wg.path]);
      await _writeTool(scratch, 'ip', 'exit 0\n');
      if (!copies) {
        // A full disk: the copy without the line is not written.
        final grep = File('${scratch.path}/grep')
          ..writeAsStringSync('#!/bin/sh\ncase "\$1" in -vxF) exit 2;; esac\nexec /usr/bin/grep "\$@"\n');
        await Process.run('chmod', ['700', grep.path]);
      }
      expect(
        hostVpnDownCommand(host: 'demo', interface: 'porelo', networkNumber: 0)[3],
        startsWith('PATH=/usr/bin:/usr/sbin:/bin:/sbin\n'),
        reason: 'root\'s own PATH, none of the person\'s; the test puts its stand-ins before it',
      );
      final script = hostVpnDownCommand(host: 'demo', interface: 'porelo', networkNumber: 0)[3]
          .replaceAll('/etc/hosts', hosts.path)
          .replaceAll('mktemp -p /tmp', 'mktemp -p ${scratch.path}')
          .replaceAll('PATH=/usr/bin:/usr/sbin:/bin:/sbin', 'PATH=${scratch.path}:/usr/bin:/bin');
      final result = await Process.run('/bin/sh', ['-c', script, 'porelo-vpn-down', 'demo', '0', 'porelo']);
      expect(result.exitCode == 0, downs && copies, reason: '${result.stderr}');
      expect(
        hosts.readAsStringSync(),
        downs && copies ? '127.0.0.1 localhost\n10.0.0.5 mine # porelo-host\n' : '127.0.0.1 localhost\n10.73.0.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo\n10.0.0.5 mine # porelo-host\n',
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
      Directory('${scratch.path}/state').createSync();
      etc = Directory('${scratch.path}/etc')..createSync();
      Directory('${etc.path}/wireguard').createSync();
      hosts = File('${etc.path}/hosts')..writeAsStringSync('127.0.0.1 localhost\n');
      capture = File('${scratch.path}/capture');
    });
    tearDown(() => scratch.deleteSync(recursive: true));

    Future<ProcessResult> up({
      String? forgeCa,
      String host = 'demo',
      int networkNumber = 0,
      String store = 'update-ca-certificates',
      bool storeTakes = true,
      String? argument,
    }) async {
      final tools = <String, String>{
        'sudo': r'exec "$@"',
        'ip': r'''case "$1" in
  link) printf '%s\n' "$6" > "$VPN_STATE/$4";;
  -o)
    if [ "$#" = 3 ]; then
      for file in "$VPN_STATE"/porelo-*; do
        [ ! -f "$file" ] || printf '1: %s: alias %s\n' "${file##*/}" "$(cat "$file")"
      done
    else
      [ -f "$VPN_STATE/$5" ] && printf '1: %s: alias %s\n' "$5" "$(cat "$VPN_STATE/$5")"
    fi;;
  *) exit 1;;
esac''',
        'wg-quick': r'''case "$1" in
  up) touch "$VPN_STATE/$2";;
  down) rm -f -- "$VPN_STATE/$2";;
  *) exit 1;;
esac''',
        'ping': r'''[ "$5" = "10.73.$VPN_NETWORK.1" ]''',
        'date': "printf '100\\n'",
        'sleep': 'exit 0',
        if (store.isNotEmpty)
          store: '''printf '%s\\n' '$store' >> "\$VPN_CAPTURE"\n${storeTakes ? 'exit 0' : 'exit 1'}''',
        'wg': r'''case "$*" in
  'show interfaces')
    for file in "$VPN_STATE"/porelo-*; do
      [ ! -f "$file" ] || printf '%s\n' "${file##*/}"
    done;;
  'show porelo-0 endpoints'|'show porelo-17 endpoints') printf 'expected-key\t203.0.113.7:51820\n';;
  'show porelo-0 latest-handshakes'|'show porelo-17 latest-handshakes') printf 'expected-key\t101\n';;
  *) exit 1;;
esac''',
      };
      for (final entry in tools.entries) {
        final file = File('${scratch.path}/${entry.key}')..writeAsStringSync('#!/bin/sh\n${entry.value}\n');
        await Process.run('chmod', ['700', file.path]);
      }
      final command = hostVpnUpCommand(
        source.path,
        commandPath: '${scratch.path}:/usr/bin:/bin',
        forgeCa: forgeCa,
        host: host,
        networkNumber: networkNumber,
      );
      command[3] = command[3]
          .replaceAll('/etc/', '${etc.path}/')
          .replaceAll('/usr/local/share/', '${scratch.path}/usr/local/share/')
          .replaceAll('mktemp -p /tmp', 'mktemp -p ${scratch.path}');
      if (argument != null) command[command.length - 1] = argument;
      return Process.run(
        command.first,
        command.skip(1).toList(),
        environment: {
          'PATH': '${scratch.path}:/usr/bin:/bin',
          'VPN_CAPTURE': capture.path,
          'VPN_STATE': '${scratch.path}/state',
          'VPN_NETWORK': '$networkNumber',
        },
      );
    }

    Future<ProcessResult> down(String host, int network) async {
      final command = hostVpnDownCommand(host: host, networkNumber: network, interface: 'porelo-$network');
      command[3] = command[3]
          .replaceAll('/etc/', '${etc.path}/')
          .replaceAll('/usr/local/share/', '${scratch.path}/usr/local/share/')
          .replaceAll('mktemp -p /tmp', 'mktemp -p ${scratch.path}')
          .replaceAll('PATH=/usr/bin:/usr/sbin:/bin:/sbin', 'PATH=${scratch.path}:/usr/bin:/bin');
      return Process.run(
        '/bin/sh',
        command.skip(2).toList(),
        environment: {'VPN_CAPTURE': capture.path, 'VPN_STATE': '${scratch.path}/state'},
      );
    }

    File inStore() => File('${scratch.path}/usr/local/share/ca-certificates/porelo-host-demo.crt');
    File forFirefox() => File('${etc.path}/firefox/porelo/porelo-host-demo.crt');
    File policy() => File('${etc.path}/firefox/policies/policies.json');

    test('nothing of it without a CA a stop gave', () async {
      final none = await up();
      expect(none.exitCode, 0, reason: '${none.stdout}${none.stderr}');
      expect(Directory('${etc.path}/firefox').existsSync(), isFalse);
      expect(hosts.readAsStringSync(), '127.0.0.1 localhost\n');
    });

    // Recreating a host on another network must not route its commands to the old server.
    test('recreated host names resolve only to its current network', () async {
      expect((await up(forgeCa: ca)).exitCode, 0);
      hosts.writeAsStringSync(
        '${hosts.readAsStringSync()}10.73.9.1 forge.other.porelo.internal matrix.other.porelo.internal # porelo-host-other\n',
      );
      hosts.writeAsStringSync(
        '${hosts.readAsStringSync()}10.73.17.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo\n',
      );
      final result = await up(forgeCa: ca, networkNumber: 17);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final entries = hosts.readAsLinesSync();
      expect(entries.where((line) => line.endsWith('# porelo-host-demo')), [
        '10.73.17.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo',
      ]);
      expect(
        entries,
        contains('10.73.9.1 forge.other.porelo.internal matrix.other.porelo.internal # porelo-host-other'),
      );
    });

    // A reboot removes the link but must not keep a retired server's names and trusted CA.
    test('VPN down removes names and trust after the kernel link is gone', () async {
      expect((await up(forgeCa: ca)).exitCode, 0);
      File('${scratch.path}/state/porelo-0').deleteSync();
      final result = await down('demo', 0);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(hosts.readAsStringSync(), '127.0.0.1 localhost\n');
      expect(inStore().existsSync(), isFalse);
      expect(forFirefox().existsSync(), isFalse);
    });

    test('put in place once, the policy naming the copy a snap reads, the name on a line of its own', () async {
      hosts.writeAsStringSync('127.0.0.1 localhost\n192.168.1.50 nas.local');
      final first = await up(forgeCa: ca);
      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      expect(inStore().readAsStringSync(), ca);
      expect(forFirefox().readAsStringSync(), ca);
      // The test moved /etc into its scratch folder, the policy's path with it.
      expect(policy().readAsStringSync(), contains('"Install":["${etc.path}/firefox/porelo/porelo-host-demo.crt"]'));
      expect(capture.readAsLinesSync(), ['update-ca-certificates'], reason: 'the system store is told once');
      expect(
        hosts.readAsStringSync(),
        '127.0.0.1 localhost\n192.168.1.50 nas.local\n10.73.0.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo\n',
        reason: 'the person\'s last line stays as it was',
      );
      expect(File('${source.path}.checked').existsSync(), isTrue);

      final copied = forFirefox().statSync().modified;
      final again = await up(forgeCa: ca);
      expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
      expect(capture.readAsLinesSync(), ['update-ca-certificates'], reason: 'the same CA is not put in again');
      expect(forFirefox().statSync().modified, copied, reason: 'nor Firefox\'s copy');
      expect('forge.demo.porelo.internal'.allMatches(hosts.readAsStringSync()), hasLength(1), reason: 'the name once');
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
      expect('${linked.stdout}', contains('Firefox has a policy of its own'));

      // Staged under a name of its own making: a link at a name known in advance leads nowhere.
      Link(policy().path).deleteSync();
      final elsewhere = File('${scratch.path}/elsewhere')..writeAsStringSync('mine\n');
      for (final known in ['policies.json.new', '.policies.json.new', 'policies.json.tmp']) {
        Link('${etc.path}/firefox/policies/$known').createSync(elsewhere.path);
      }
      final staged = await up(forgeCa: ca);
      expect(staged.exitCode, 0, reason: '${staged.stdout}${staged.stderr}');
      expect(elsewhere.readAsStringSync(), 'mine\n');
      expect(policy().readAsStringSync(), contains('porelo-host-demo.crt'));
    });

    test('Fedora\'s store, and no store at all', () async {
      final fedora = await up(forgeCa: ca, store: 'update-ca-trust');
      expect(fedora.exitCode, 0, reason: '${fedora.stdout}${fedora.stderr}');
      expect(File('${etc.path}/pki/ca-trust/source/anchors/porelo-host-demo.crt').readAsStringSync(), ca);
      expect(capture.readAsLinesSync(), ['update-ca-trust']);

      capture.deleteSync();
      File('${scratch.path}/update-ca-trust').deleteSync();
      final none = await up(forgeCa: ca, store: '');
      expect(none.exitCode, 0, reason: '${none.stdout}${none.stderr}');
      expect('${none.stdout}', contains('no tool for a system store of certificates'));
      expect(capture.existsSync(), isFalse);
      expect(forFirefox().readAsStringSync(), ca, reason: 'Firefox trusts it all the same');
      expect(File('${source.path}.checked').existsSync(), isTrue);
    });

    test('a store that does not take it is tried again', () async {
      final refused = await up(forgeCa: ca, storeTakes: false);
      expect(refused.exitCode, isNot(0));
      expect(inStore().existsSync(), isFalse, reason: 'taken back, so the next start tries again');
      expect(File('${source.path}.checked').existsSync(), isFalse, reason: 'no receipt where it failed');
      final retried = await up(forgeCa: ca);
      expect(retried.exitCode, 0, reason: '${retried.stdout}${retried.stderr}');
      expect(capture.readAsLinesSync(), ['update-ca-certificates', 'update-ca-certificates']);
    });

    // Harm: trusting a second host replaces the first host's CA or removes its service names.
    test('a second host installs its own trust and names without replacing the first', () async {
      final first = await up(forgeCa: ca);
      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      expect(
        File('${etc.path}/wireguard/porelo-0.conf').existsSync(),
        isTrue,
        reason: 'each host needs its own interface configuration',
      );
      final otherCa = ca.replaceFirst('AAEC', 'AQEC');
      final second = await up(forgeCa: otherCa, host: 'second', networkNumber: 17);
      expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
      expect(inStore().readAsStringSync(), ca);
      expect(forFirefox().readAsStringSync(), ca);
      expect(
        File('${scratch.path}/usr/local/share/ca-certificates/porelo-host-second.crt').readAsStringSync(),
        otherCa,
      );
      expect(File('${etc.path}/firefox/porelo/porelo-host-second.crt').readAsStringSync(), otherCa);
      expect(File('${etc.path}/wireguard/porelo-17.conf').existsSync(), isTrue);
      expect(hosts.readAsLinesSync(), [
        '127.0.0.1 localhost',
        '10.73.0.1 forge.demo.porelo.internal matrix.demo.porelo.internal # porelo-host-demo',
        '10.73.17.1 forge.second.porelo.internal matrix.second.porelo.internal # porelo-host-second',
      ]);
    });

    // Harm: a dormant colliding record must not take the active host's tunnel down.
    test('down refuses another owner before changing its tunnel names or trust', () async {
      expect((await up(forgeCa: ca)).exitCode, 0);
      final result = await down('second', 0);
      expect(result.exitCode, isNot(0));
      expect('${result.stdout}', allOf(contains('demo'), contains('second')));
      expect(File('${scratch.path}/state/porelo-0').readAsStringSync(), 'porelo-host-demo\n');
      expect(hosts.readAsStringSync(), contains('forge.demo.porelo.internal'));
      expect(inStore().readAsStringSync(), ca);
    });

    // Harm: taking one host down must not remove another host's route, names, or trust.
    test('taking either host down leaves the other host connected and trusted', () async {
      for (final host in ['demo', 'second']) {
        expect((await up(forgeCa: ca)).exitCode, 0);
        expect((await up(forgeCa: ca, host: 'second', networkNumber: 17)).exitCode, 0);
        final result = await down(host, host == 'demo' ? 0 : 17);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final other = host == 'demo' ? 'second' : 'demo';
        expect(Directory('${scratch.path}/state').listSync().map((file) => file.uri.pathSegments.last), [
          other == 'demo' ? 'porelo-0' : 'porelo-17',
        ], reason: 'only the other interface stays up');
        expect(hosts.readAsStringSync(), isNot(contains('porelo-host-$host\n')));
        expect(hosts.readAsStringSync(), contains('porelo-host-$other\n'));
        for (final base in ['${scratch.path}/usr/local/share/ca-certificates', '${etc.path}/firefox/porelo']) {
          expect(File('$base/porelo-host-$host.crt').existsSync(), isFalse);
          expect(File('$base/porelo-host-$other.crt').readAsStringSync(), ca);
        }
        expect(File('${etc.path}/wireguard/${other == 'demo' ? 'porelo-0' : 'porelo-17'}.conf').existsSync(), isTrue);
      }
    });

    test('what is not one certificate is refused, here and by root', () async {
      for (final bad in [
        '-----BEGIN CERTIFICATE-----\nAAAA-----END CERTIFICATE-----\n',
        '-----BEGIN CERTIFICATE-----\n\n-----END CERTIFICATE-----\n',
        '$ca$ca',
        "-----BEGIN CERTIFICATE-----\nAAAA'\n-----END CERTIFICATE-----\n",
        '-----BEGIN CERTIFICATE-----\n${'A' * 76}==\n-----END CERTIFICATE-----\n',
        '-----BEGIN CERTIFICATE-----\n${'A' * 80}\n-----END CERTIFICATE-----\n',
        '-----BEGIN CERTIFICATE-----\nA\n-----END CERTIFICATE-----\n',
        '-----BEGIN CERTIFICATE-----\n====\n-----END CERTIFICATE-----\n',
      ]) {
        expect(isForgeCaCertificate(bad), isFalse, reason: bad);
        expect(() => hostVpnUpCommand(source.path, host: 'demo', forgeCa: bad), throwsFormatException);
      }
      // Root's own check, should something else reach it: each of its parts on its own, nothing installed, no receipt.
      const begin = '-----BEGIN CERTIFICATE-----';
      const end = '-----END CERTIFICATE-----';
      for (final bad in [
        '$begin\n$end',
        '$end\nAAAA\n$end',
        '$begin\nAAAA\n$begin',
        '$begin\nAAAA\n$end\nextra',
        '$begin\n${'A' * 80}\n$end',
        '$begin\nAAA\u00e9\n$end',
        '$begin\nA\n$end',
        '$ca${ca.trimRight()}',
      ]) {
        final reached = await up(forgeCa: ca, argument: bad);
        expect(reached.exitCode, isNot(0), reason: bad);
        expect('${reached.stdout}', contains('not one certificate'), reason: bad);
        expect(inStore().existsSync(), isFalse);
        expect(forFirefox().existsSync(), isFalse);
        expect(File('${source.path}.checked').existsSync(), isFalse);
      }
      final good = await up(forgeCa: ca, argument: '$begin\n${'A' * 76}\n$end');
      expect(good.exitCode, 0, reason: 'a line of the full width is a certificate\'s: ${good.stdout}${good.stderr}');
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
      final configuration = File('${scratch.path}/etc/NetworkManager/conf.d/porelo-0.conf');
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
      final wireguard = File('${scratch.path}/etc/wireguard/porelo-0.conf');
      wireguard.parent.createSync(recursive: true);
      final source = File('${scratch.path}/source.conf')
        ..writeAsStringSync('[Peer]\nPublicKey = expected-key\nEndpoint = 203.0.113.7:51820\n');
      final capture = File('${scratch.path}/capture');
      final scripts = <String, String>{
        'ip': 'exit 0\n',
        'date': "printf '100\\n'\n",
        'sleep': 'exit 0\n',
        'ping': 'exit 0\n',
        'wg': r'''case "$*" in
  'show interfaces') printf 'porelo-0\n';;
  'show porelo-0 endpoints') printf 'expected-key\t203.0.113.7:51820\n';;
  'show porelo-0 latest-handshakes'|'show porelo-17 latest-handshakes') printf 'expected-key\t101\n';;
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
      final command = hostVpnUpCommand(source.path, host: 'demo', commandPath: tools.path);
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

const _unmanagedRule = '[keyfile]\nunmanaged-devices=interface-name:porelo-0\n';

Future<void> _writeTool(Directory directory, String name, String script) async {
  final file = File('${directory.path}/$name')..writeAsStringSync('#!/bin/sh\n$script');
  final result = await Process.run('/usr/bin/chmod', ['700', file.path]);
  expect(result.exitCode, 0, reason: 'the isolated tool must be executable');
}

class _VpnSecrets implements SecretStore {
  final privateKey = base64Encode(List<int>.filled(32, 7));

  @override
  Future<String?> read(String name) async => name == HostFiles.keyName('second') ? privateKey : null;

  @override
  Future<void> close() async {}

  @override
  Future<void> remove(String name) async {}

  @override
  Future<void> write(String name, String value) async {}
}
