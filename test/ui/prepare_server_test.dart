import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_frontend/src/ui/host_admin_dialog.dart';

import '../support/host_admin.dart';
import '../features/support/world.dart';
import '../support/host_process.dart';

void main() {
  late Directory scratch;
  late Settings settings;
  late Machines machines;
  late HostRuns runs;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('prepare-server-');
    final key = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-f', '${scratch.path}/rental']);
    expect(key.exitCode, 0);
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    runs = HostRuns(machines);
  });
  tearDown(() async {
    runs.dispose();
    machines.dispose();
    settings.dispose();
    await scratch.delete(recursive: true);
  });
  Future<void> frame(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await World.settle(tester);
  }

  Future<void> next(WidgetTester tester) async {
    // Text edits schedule a rebuild; tapping the old disabled button cannot advance the wizard.
    await World.settle(tester);
    final button = find.byKey(const Key('wizard-next'));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull, reason: 'the current answers must enable Next');
    await tester.tap(button);
    await World.settle(tester);
  }

  // Harm: reusing a known host's network can route administrator traffic to the wrong server.
  testWidgets('server preparation proposes the lowest network absent from every host record', (tester) async {
    for (final n in [0, 1, 3]) {
      await settings.rememberHostUp(
        'known-$n',
        HostUpRecord(
          host: 'known-$n',
          vpnNetworkNumber: n,
          vpnInterface: 'porelo-$n',
          scalewayProject: 'provider',
          account: 'worker',
          tresor: '',
          folder: null,
          signingKey: '',
          identity: '/keys/rental',
          publicKey: '/keys/rental.pub',
          collection: '',
          vpnPeerPublicKey: '',
          vpnPeerAddress: '',
        ),
      );
    }
    await frame(
      tester,
      HostDialog(
        project: '',
        machines: machines,
        settings: settings,
        hostRuns: runs,
        debug: false,
        checkKey: (_, _) async => HostProcess()..end(0),
      ),
    );
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'provider');
    await next(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('host-network'))).controller!.text, '2');
    await tester.enterText(find.byKey(const Key('host-name')), 'orchard');
    await tester.enterText(find.byKey(const Key('host-network')), '3');
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: renting a server must not upload a project or create its account.
  // Linux: preparing a server needs the secrets file, which Windows does not offer (noSecretsFileHere), and this
  // test makes a real one with /usr/bin/keepassxc-cli.
  testWidgets('preparing a server runs up without a project and feeds only the root stop', (tester) async {
    final commands = <List<String>>[];
    final process = HostProcess();
    final terminals = <FakeTerminal>[];
    await frame(
      tester,
      HostDialog(
        project: '',
        machines: machines,
        settings: settings,
        hostRuns: runs,
        debug: false,
        secretStore: MemorySecrets(),
        checkKey: (_, _) async => HostProcess()..end(0),
        start: (_, arguments) async {
          commands.add(List.of(arguments));
          return process;
        },
        openTerminal: (program, arguments, {columns = 80, rows = 24}) {
          final terminal = FakeTerminal([program, ...arguments]);
          terminals.add(terminal);
          return terminal;
        },
      ),
    );
    expect(find.text('Prepare a server'), findsOneWidget);
    expect(find.byKey(const Key('host-account')), findsNothing);
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'provider');
    await next(tester);
    expect(find.text('The project'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('host-network'))).controller!.text, '0');
    await tester.enterText(find.byKey(const Key('host-name')), 'orchard');
    await tester.enterText(find.byKey(const Key('host-network')), '7');
    await next(tester);
    await tester.enterText(find.byKey(const Key('host-identity')), '${scratch.path}/rental');
    await tester.enterText(find.byKey(const Key('host-public-key')), '${scratch.path}/rental.pub');
    await next(tester);
    final secretsPath = '${scratch.path}/secrets.kdbx';
    await tester.enterText(find.byKey(const Key('host-secrets-file')), secretsPath);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-secrets-open')));
    await World.settle(tester);
    for (var i = 0; i < 100 && terminals.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(terminals, hasLength(1), reason: 'the real secrets preparation must open its terminal');
    final secretsTerminal = terminals.single;
    final prepared = await tester.runAsync(() async {
      final command = secretsTerminal.command;
      final child = await Process.start(command.first, command.skip(1).toList());
      final stdout = child.stdout.transform(utf8.decoder).join();
      final stderr = child.stderr.transform(utf8.decoder).join();
      child.stdin.write('fixture-master\nfixture-master\n');
      await child.stdin.close();
      return ProcessResult(child.pid, await child.exitCode, await stdout, await stderr);
    });
    expect(prepared!.exitCode, 0, reason: '${prepared.stderr}');
    secretsTerminal.endsWith(0);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
    // Closing the terminal precedes reading its public result and removing its temporary directory.
    for (var i = 0; i < 100 && settings.secretsFile != secretsPath; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(settings.secretsFile, secretsPath, reason: 'public-key readback must finish before setup starts');
    final listing = await tester.runAsync(() async {
      final child = await Process.start(SecretsFile.keepassxcCli, ['ls', '-R', secretsPath]);
      final stdout = child.stdout.transform(utf8.decoder).join();
      final stderr = child.stderr.transform(utf8.decoder).join();
      child.stdin.writeln('fixture-master');
      await child.stdin.close();
      return ProcessResult(child.pid, await child.exitCode, await stdout, await stderr);
    });
    expect(listing!.exitCode, 0, reason: '${listing.stderr}');
    expect(listing.stdout, contains('orchard/'));
    expect(listing.stdout, contains('wireguard'));
    expect(listing.stdout, isNot(contains('projects/')));
    expect(listing.stdout, isNot(contains('vault-passphrase')));
    terminals.clear();
    await next(tester);
    expect(find.byKey(const Key('host-signing-key')), findsNothing);
    expect(commands, isEmpty, reason: 'renting needs the review decision');
    await tester.tap(find.byKey(const Key('host-up')));
    await tester.pump();
    for (var i = 0; i < 100 && commands.isEmpty && terminals.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(terminals, isEmpty, reason: 'setup must reuse the public key read from the completed secrets terminal');
    expect(commands, hasLength(1));
    expect(
      commands.single,
      containsAllInOrder(['up', '--host-name', 'orchard', '--network', '7', '--login-user', 'root', '--forge', 'true']),
    );
    for (final option in ['--project', '--account', '--authorized-key', '--machine-file', '--bundle']) {
      expect(commands.single, isNot(contains(option)));
    }
    process.line(
      const Step(
        'person',
        StepState.waiting,
        needs: ['wireguard', 'forge-certificate'],
        address: '203.0.113.7',
        admin: 'root',
      ),
    );
    process.end(75);
    await World.settle(tester);
    final run = runs.of('orchard')!;
    final kept = settings.hostUp('orchard')!;
    expect(kept.host, 'orchard');
    expect(kept.vpnNetworkNumber, 7);
    expect(kept.vpnInterface, 'porelo-7');
    final restored = HostUpRecord.fromStored(kept.stored)!;
    expect(restored.host, 'orchard');
    expect(restored.vpnNetworkNumber, 7);
    expect(restored.vpnInterface, 'porelo-7');
    await tester.pumpWidget(const SizedBox.shrink());
    await frame(
      tester,
      HostStopDialog(
        run: run,
        hostRuns: runs,
        machines: machines,
        settings: settings,
        openTerminal: (program, arguments, {columns = 80, rows = 24}) {
          final terminal = FakeTerminal([program, ...arguments]);
          terminals.add(terminal);
          return terminal;
        },
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('host-open-terminal')));
    await tester.tap(find.byKey(const Key('host-open-terminal')));
    await World.settle(tester);
    expect(terminals, hasLength(1));
    final script = terminals.single.command.last;
    expect(script, contains('root@203.0.113.7'));
    expect(script, contains('hosts/orchard/wireguard'));
    expect(script, isNot(contains('projects/orchard/')));
    expect(script, isNot(contains('hosts/orchard/vault-passphrase')));
    expect(script, contains('hosts/orchard/forge-ca'));
    expect(script, contains('permitted;IP:10.73.7.0/255.255.255.0'));
    expect(script, contains('DNS:forge.orchard.porelo.internal,IP:10.73.7.1'));
    expect(script, contains('DNS:matrix.orchard.porelo.internal,IP:10.73.7.1'));
    expect(script, contains('porelo-host-stop --stdin wireguard forge-certificate'));
    for (final other in ['vault-new', 'matrix-token', 'drive-login', ' --stdin keys']) {
      expect(script, isNot(contains(other)));
    }
    terminals.single.endsWith(75);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  }, tags: 'linux');

  // An asynchronous VPN refresh must complete cleanup for the server actually given back.
  // Linux: the VPN cleanup it checks runs only where HostRuns finds Platform.isLinux.
  testWidgets('server-only give-back observes its host VPN refresh', (tester) async {
    var linkUp = true;
    runs.dispose();
    runs = HostRuns(machines, probeLink: () async => linkUp, ping: () async => false);
    final record = HostUpRecord(
      host: 'orchard',
      hostName: 'orchard',
      scalewayProject: 'provider',
      account: 'root',
      tresor: '',
      folder: null,
      signingKey: '',
      identity: '${scratch.path}/rental',
      publicKey: '${scratch.path}/rental.pub',
      collection: '',
      vpnPeerPublicKey: '',
      vpnPeerAddress: '',
      vpnNetworkNumber: 7,
      vpnInterface: 'porelo-7',
    );
    await settings.rememberHostUp('orchard', record);
    final process = HostProcess();
    final run = HostPreparation(
      project: 'orchard',
      record: record,
      session: HostSession(executable: 'fake', arguments: record.arguments('orchard'), start: (_, _) async => process),
    );
    final terminal = FakeTerminal([]);
    await frame(
      tester,
      HostDialog(
        project: '',
        existingRun: run,
        machines: machines,
        settings: settings,
        hostRuns: runs,
        takeDownOnly: true,
        openTerminal: (_, _, {columns = 80, rows = 24}) => terminal,
      ),
    );
    await tester.tap(find.byKey(const Key('host-down')));
    await World.settle(tester);
    process.line(const Step('give-back', StepState.done, address: '203.0.113.7'));
    process.end(0);
    await World.settle(tester);
    terminal.endsWith(65);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
    expect(find.byKey(const Key('host-done')), findsNothing);
    linkUp = false;
    await runs.refreshVpns();
    await World.settle(tester);
    expect(find.byKey(const Key('host-done')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, tags: 'linux');

  // Harm: completed server preparation must not invent a project account or daemon.
  testWidgets('a completed server retains its checked public values without a project daemon', (tester) async {
    final process = HostProcess();
    final record = HostUpRecord(
      scalewayProject: 'provider',
      account: 'root',
      tresor: '',
      folder: null,
      signingKey: '',
      identity: '${scratch.path}/rental',
      publicKey: '${scratch.path}/rental.pub',
      collection: '',
      vpnPeerPublicKey: wireGuardKey,
      vpnPeerAddress: '10.73.7.2/32',
      vpnHostPublicKey: wireGuardKey,
      hostName: 'orchard',
      host: 'orchard',
      vpnNetworkNumber: 7,
      vpnInterface: 'porelo-7',
    );
    final run = runs.start(
      project: 'orchard',
      record: record,
      session: HostSession(executable: 'fake', arguments: record.arguments('orchard'), start: (_, _) async => process),
    );
    process.line(const Step('up', StepState.done, address: '203.0.113.7', admin: 'root'));
    process.raw(jsonEncode({'v': 1, 'state': 'host', 'host': hostValues()}));
    process.end(0);
    await World.settle(tester);
    expect(run.awaitingVpn, isTrue);
    expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
    expect(settings.hostUp('orchard')!.preparing, isTrue);
    await runs.vpnChecked(run, verified: false);
    expect(run.ready, isFalse, reason: 'an unverified VPN must keep recovery');
    await runs.vpnChecked(run, verified: true);
    expect(run.ready, isTrue);
    final server = machines.all.singleWhere((machine) => machine.hostProject == 'orchard');
    expect(server.host, 'root@203.0.113.7');
    expect(server.remoteSocket, isEmpty);
    expect(settings.hostUp('orchard')!.preparing, isFalse);
    final kept = settings.hostUp('orchard')!;
    for (final copy in [
      kept,
      kept.withPreparation(DateTime.utc(2020)),
      kept.withProtocol(const []),
      kept.withVpnFile('/private/porelo-7.conf'),
      kept.withTunnel(hostPublicKey: wireGuardKey, address: '203.0.113.7'),
      kept.withForgeCa(null),
    ]) {
      final restored = HostUpRecord.fromStored(copy.stored)!;
      expect(restored.preparedHost!.values, hostValues());
      expect(restored.host, 'orchard');
      expect(restored.vpnNetworkNumber, 7);
      expect(restored.vpnInterface, 'porelo-7');
      expect(restored.arguments('orchard'), containsAllInOrder(['--host-name', 'orchard', '--network', '7']));
    }
    expect(HostUpRecord.fromStored({...kept.stored, 'host': 'another'}), isNull);
    expect(HostUpRecord.fromStored({...kept.stored, 'vpnNetworkNumber': 8}), isNull);
    expect(
      HostUpRecord.fromStored({
        ...kept.stored,
        'preparedHost': {...hostValues(), 'network': '10.73.8.0/24'},
      }),
      isNull,
    );
    for (final linkUp in [true, false]) {
      final commands = hostMachineCommands(
        machine: server,
        settings: settings,
        takeDown: () {},
        saveTunnel: () {},
        bringVpnUp: () {},
        takeVpnDown: () {},
        vpnLinkUp: linkUp,
      );
      expect(commands.every((command) => command.available), isTrue, reason: 'prepared hosts use per-host VPN actions');
    }
    await frame(
      tester,
      HostDialog(project: 'orchard', existingRun: run, machines: machines, settings: settings, hostRuns: runs),
    );
    expect(find.text('For the project admins'), findsOneWidget);
    for (final name in [...hostValues().keys, 'SSH fingerprint']) {
      expect(find.byKey(ValueKey('host-copy $name')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: the terminal boundary must not lose a refusal or assume removal before the host confirms it.
  for (final code in [65, 0]) {
    testWidgets(
      code == 65
          ? 'the project removal refusal appears verbatim in its own place'
          : 'project removal shows the confirmed answer after the terminal closes',
      (tester) async {
        const refusal = 'porelo-host-project: unpushed work remains.\n';
        final remote = HelperRemote();
        FakeTerminal? terminal;
        late String replies;
        await frame(
          tester,
          HostAdminDialog(
            host: PreparedHost.read(hostValues()),
            action: 'remove',
            remote: remote,
            secretsFile: '${scratch.path}/secrets.kdbx',
            identity: '${scratch.path}/rental',
            knownHosts: '${scratch.path}/known-hosts',
            openTerminal: (program, arguments, {columns = 80, rows = 24}) {
              final script = arguments.last;
              replies = RegExp(r'> (\S+)/answer 2>').firstMatch(script)!.group(1)!;
              File('$replies/answer').writeAsStringSync(code == 0 ? '{"project":"orchard","removed":true}\n' : '');
              File('$replies/refusal').writeAsStringSync(code == 65 ? refusal : '');
              return terminal = FakeTerminal([program, ...arguments]);
            },
          ),
        );
        await tester.enterText(find.byKey(const Key('host-admin-name')), 'orchard');
        await next(tester);
        expect(remote.commands, isEmpty);
        await tester.tap(find.byKey(const Key('wizard-start')));
        await World.settle(tester);
        for (var attempt = 0; attempt < 100 && terminal == null; attempt++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          });
          await World.settle(tester);
        }
        await World.settle(tester);
        expect(terminal, isNotNull);
        expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
        expect(find.byKey(const Key('host-admin-answer')), findsNothing);
        expect(terminal!.command.last, contains('root@10.73.7.1'));
        expect(terminal!.command.last, contains('porelo-host-project remove orchard'));
        terminal!.prints(code == 65 ? refusal : '{"project":"orchard","removed":true}\r\n');
        terminal!.endsWith(code);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 100 && Directory(replies).existsSync(); attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await World.settle(tester);
        if (code == 65) {
          expect(tester.widget<SelectableText>(find.byKey(const Key('host-admin-refusal'))).data, refusal);
        } else {
          expect(
            tester.widget<SelectableText>(find.byKey(const Key('host-admin-answer'))).data,
            'The project orchard was taken off the server.',
          );
        }
        expect(remote.commands, isEmpty, reason: 'removal must run in the secrets terminal');
        expect(Directory(replies).existsSync(), isFalse, reason: 'only the public reply files were temporary');
        await tester.pumpWidget(const SizedBox.shrink());
      },
      // Linux: the removal pipes its token from the secrets file, which Windows does not offer (noSecretsFileHere).
      tags: 'linux',
    );
  }

  // Harm: root helpers trusting the public address or another rental's file reach the wrong machine as root.
  test('the host helpers pin the host key at its VPN address in a trust file of this host alone', () async {
    final record = HostUpRecord(
      host: 'orchard',
      hostName: 'orchard',
      scalewayProject: 'provider',
      preparedHost: PreparedHost.read(hostValues()),
      account: 'root',
      tresor: '',
      folder: null,
      signingKey: '',
      identity: '${scratch.path}/rental',
      publicKey: '${scratch.path}/rental.pub',
      collection: '',
      vpnPeerPublicKey: '',
      vpnPeerAddress: '',
      vpnNetworkNumber: 7,
      vpnInterface: 'porelo-7',
    );
    final environment = {'XDG_STATE_HOME': scratch.path, 'LOCALAPPDATA': scratch.path};
    final (:remote, :trust) = hostAdminRemote(record, environment: environment);
    expect(remote.knownHosts.path, '${poreloHostKnownHosts(environment: environment)}.orchard');
    expect(remote.knownHosts.path, startsWith(scratch.path));
    expect(remote.identity, '${scratch.path}/rental');
    await trust();
    expect(remote.knownHosts.readAsStringSync(), '10.73.7.1 ${hostValues()['ssh_host_key']}\n');
  });

  // Harm: a purge must require a separate permanent-removal decision.
  testWidgets('purge waits for a second decision after review', (tester) async {
    final remote = HelperRemote(response: '{"person":"alice","purged":true}');
    // Harm: a helper call before the host's key is pinned trusts whatever answers at the address.
    bool? pinnedFirst;
    await frame(
      tester,
      HostAdminDialog(
        host: PreparedHost.read(hostValues()),
        action: 'purge',
        remote: remote,
        // The pinning waits a turn, as writing known_hosts does, so a call made without awaiting it shows.
        prepareRemote: () async {
          await Future<void>.delayed(Duration.zero);
          pinnedFirst = remote.commands.isEmpty;
        },
      ),
    );
    await tester.enterText(find.byKey(const Key('host-admin-name')), 'alice');
    await next(tester);
    await tester.tap(find.byKey(const Key('wizard-start')));
    await World.settle(tester);
    expect(remote.commands, isEmpty);
    await tester.tap(find.text('Purge permanently'));
    await World.settle(tester);
    expect(remote.commands.single, '/usr/local/sbin/porelo-host-person purge alice');
    expect(pinnedFirst, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: helper actions must not reach a server while setup owns it.
  test('prepared server commands keep their reasons and their pointer homes', () async {
    final record = HostUpRecord(
      scalewayProject: 'provider',
      account: 'root',
      tresor: '',
      folder: null,
      signingKey: '',
      identity: '/keys/rental',
      publicKey: '/keys/rental.pub',
      collection: '',
      vpnPeerPublicKey: wireGuardKey,
      vpnPeerAddress: '10.73.7.2/32',
      hostName: 'orchard',
      host: 'orchard',
      vpnNetworkNumber: 7,
      vpnInterface: 'porelo-7',
    );
    final server = Machine(
      name: 'orchard',
      socketPath: '',
      kind: 'host',
      identity: record.identity,
      hostProject: 'orchard',
    );
    await settings.rememberHostUp('orchard', record);
    final commands = preparedHostCommands(machine: server, settings: settings, open: (_) {}, showValues: () {});
    expect(commands.map((command) => command.id), [
      'host.adminValues',
      'host.registerProject',
      'host.removeProject',
      'host.admitAdmin',
      'host.lockAdmin',
      'host.purgeAdmin',
    ]);
    expect(
      commands.every(
        (command) => command.home == Home.machineMenu && command.unavailable == 'complete the server setup first',
      ),
      isTrue,
    );
    expect(prepareServerCommand(open: () {}).home, Home.appBar);
    expect(jsonEncode(record.arguments('orchard')), isNot(contains('--project')));
  });
}
