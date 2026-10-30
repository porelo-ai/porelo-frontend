import 'package:porelo_frontend/src/app/roles.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/homeserver_publishing.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_vpn_dialog.dart';
import 'package:porelo_frontend/src/ui/host_tunnel_export.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

const _machine = Machine(name: 'demo server', kind: 'host', hostProject: 'demo', socketPath: '/unused');
const _record = HostUpRecord(
  scalewayProject: 'provider',
  account: 'porelo',
  tresor: 'drive',
  folder: null,
  repository: '',
  signingKey: '',
  identity: '/keys/private',
  publicKey: '/keys/public.pub',
  collection: '/setup',
  vpnPeerPublicKey: 'public-half',
  vpnPeerAddress: '10.73.0.2/32',
);

// The local VPN is set up only on Linux; elsewhere the step refuses before it writes a key.
final _notLinux = !Platform.isLinux;

void main() {
  setUp(() => roles = Roles.fromArguments(const ['--roles', 'host-admin,project-admin']));
  tearDown(() => roles = const Roles());
  Future<void> open(
    WidgetTester tester,
    Settings settings,
    List<List<String>> commands,
    FakeTerminal terminal, {
    bool up = true,
    bool throwsOnOpen = false,
    bool receipt = true,
    bool? linkUp,
    bool answers = false,
    ValueChanged<bool>? finished,
    bool requireFreshHandshake = false,
    SecretStore? secretStore,
    Future<bool> Function()? probeLink,
    Future<void> Function()? checkNetwork,
    DateTime Function()? now,
    String? confinement,
    ValueChanged<String>? failed,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final runtime = (await tester.runAsync(() => Directory.systemTemp.createTemp('vpn-runtime-')))!;
    addTearDown(() => runtime.delete(recursive: true));
    await tester.runAsync(() => Process.run('chmod', ['700', runtime.path]));
    final private = base64Encode(List<int>.filled(32, 7));
    final peer = await HostFiles.publicKey(private);
    final host = await HostFiles.publicKey(base64Encode(List<int>.filled(32, 9)));
    if (up) {
      final kept = settings.hostUp('demo') ?? _record;
      await settings.rememberHostUp(
        'demo',
        HostUpRecord.fromStored({...kept.stored, 'vpnPeerPublicKey': peer})!
            .withTunnel(hostPublicKey: host, address: '203.0.113.8'),
      );
    }
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              openHostVpnDialog(
                context,
                machine: _machine,
                settings: settings,
                up: up,
                probeLink: probeLink ?? () async => linkUp ?? !up,
                checkNetwork: checkNetwork,
                ping: () async => answers,
                requireFreshHandshake: requireFreshHandshake,
                secretStore: secretStore ?? _TunnelSecrets({HostFiles.keyName('demo'): private}),
                environment: {'XDG_RUNTIME_DIR': runtime.path},
                now: now ?? () => DateTime.fromMillisecondsSinceEpoch(100000),
                confinement: () => confinement,
                failed: failed,
                open: (executable, arguments, {int columns = 80, int rows = 24}) {
                  commands.add([executable, ...arguments]);
                  if (up && receipt) {
                    final source = arguments.firstWhere((arg) => arg.endsWith('/porelo.conf'));
                    File('$source.checked').writeAsStringSync('$host\t100\t101\n');
                  }
                  if (throwsOnOpen) throw const PtyRefused('invented terminal failure');
                  return terminal;
                },
              ).then((verified) {
                completed = true;
                finished?.call(verified);
              }),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    for (var turn = 0; turn < 100 && commands.isEmpty && !completed; turn++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
  }

  for (final linkUp in <bool?>[false, true, null]) {
    // Harm: routing the wrong VPN action runs an unnecessary or destructive root command.
    test('the measured link selects exactly one executable VPN action when present $linkUp', () async {
      final settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      final publicKey = base64Encode(List<int>.filled(32, 9));
      await settings.rememberHostUp(
        'demo',
        HostUpRecord.fromStored({..._record.stored, 'vpnPeerPublicKey': publicKey})!
            .withTunnel(hostPublicKey: publicKey, address: '203.0.113.8'),
      );
      final actions = <bool>[];
      final commands = hostMachineCommands(
        machine: _machine,
        settings: settings,
        takeDown: () {},
        bringVpnUp: () => actions.add(true),
        takeVpnDown: () => actions.add(false),
        vpnLinkUp: linkUp,
      ).where((command) => command.id == 'machine.vpnUp' || command.id == 'machine.vpnDown').toList();
      expect(commands.map((command) => command.id), [
        linkUp == true ? 'machine.vpnDown' : 'machine.vpnUp',
      ], reason: 'the menu and tiles must expose only the action that changes the measured link');
      expect(commands.single.available, linkUp != null, reason: 'an unknown link cannot authorize a root action');
      if (linkUp != null) {
        commands.single.run();
        expect(actions, [!linkUp], reason: 'the selected action must invoke the matching VPN operation');
      }
    });
  }

  for (final up in [true]) {
    // Harm: a no-op VPN action asks for a root password and can needlessly replace a working tunnel.
    testWidgets('VPN ${up ? 'up' : 'down'} already satisfied opens no sudo terminal', (tester) async {
      final settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      final commands = <List<String>>[];
      final secrets = _TunnelSecrets({HostFiles.keyName('demo'): base64Encode(List<int>.filled(32, 7))});
      bool? result;
      await open(
        tester,
        settings,
        commands,
        FakeTerminal([]),
        up: up,
        linkUp: up,
        answers: up,
        finished: (verified) => result = verified,
        secretStore: secrets,
      );
      expect(commands, isEmpty, reason: 'the requested state already holds, so no root action is needed');
      expect(result, isFalse, reason: 'an unprivileged probe cannot supply a fresh handshake receipt for setup');
      expect(secrets.reads, 0, reason: 'an action needing no root work must not export a private key');
    }, skip: _notLinux);
  }

  // Trust and name entries survive reboot even when the kernel link does not.
  testWidgets('VPN down opens persistent cleanup when the link is absent', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    final terminal = FakeTerminal([]);
    await open(tester, settings, commands, terminal, up: false, linkUp: false);
    expect(commands, [hostVpnDownCommand(host: 'demo', networkNumber: 0, interface: 'porelo-0')]);
    terminal.endsWith(0);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
  }, skip: _notLinux);

  // Harm: a network collision must stop the flow before a terminal can execute sudo.
  testWidgets('a colliding host network is refused before the root terminal opens', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    final terminal = FakeTerminal([]);
    await open(
      tester,
      settings,
      commands,
      terminal,
      checkNetwork: () async => throw const HostFilesRefused('The VPN for demo conflicts with the VPN for first.'),
    );
    expect(commands, isEmpty, reason: 'a collision cannot authorize a root command');
    expect(find.byKey(const Key('vpn-problem')), findsOneWidget);
  }, skip: _notLinux);

  // Harm: treating an unanswered existing link as connected strands recovery without running the needed root action.
  testWidgets('an existing link that does not answer can be brought up again', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    await open(tester, settings, commands, FakeTerminal([]), linkUp: true);
    expect(commands.length, 1, reason: 'a present link alone does not satisfy VPN up');
    expect(commands.single.first, '/usr/bin/sudo', reason: 'renewing the link requires a privileged action');
  }, skip: _notLinux);

  // Harm: a ping substituted for an expected fresh handshake can complete setup against the wrong server.
  testWidgets('setup still verifies a fresh handshake when the shared VPN address answers', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    final terminal = FakeTerminal([]);
    bool? result;
    await open(
      tester,
      settings,
      commands,
      terminal,
      linkUp: true,
      answers: true,
      requireFreshHandshake: true,
      finished: (verified) => result = verified,
    );
    expect(commands.length, 1, reason: 'setup must still run the existing fresh handshake verification');
    terminal.endsWith(0);
    for (var turn = 0; turn < 100 && result == null; turn++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(result, isTrue, reason: 'only the completed root check and its receipt confirm setup');
  }, skip: _notLinux);

  // Harm: an unhandled probe refusal hides the stop, opens sudo on guessed state, or blocks an existing platform path.
  testWidgets('unawaited VPN actions show probe refusals and preserve paths without Linux probes', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final publicKey = base64Encode(List<int>.filled(32, 9));
    await settings.rememberHostUp(
      'demo',
      HostUpRecord.fromStored({..._record.stored, 'vpnPeerPublicKey': publicKey})!
          .withTunnel(hostPublicKey: publicKey, address: '203.0.113.8'),
    );
    for (final scenario in [
      (linux: true, up: false),
      (linux: true, up: true),
      (linux: false, up: true),
      (linux: false, up: false),
    ]) {
      var probes = 0;
      bool? result;
      final commands = <List<String>>[];
      final terminal = FakeTerminal([]);
      const probeRefusal = 'The local VPN interface could not be checked.';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                openHostVpnDialog(
                  context,
                  machine: _machine,
                  settings: settings,
                  up: scenario.up,
                  linux: scenario.linux,
                  confinement: () => null,
                  environment: const {},
                  probeLink: () async {
                    probes++;
                    throw const HostFilesRefused(probeRefusal);
                  },
                  open: (executable, arguments, {int columns = 80, int rows = 24}) {
                    commands.add([executable, ...arguments]);
                    return terminal;
                  },
                ).then((verified) => result = verified),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await World.settle(tester);
      expect(tester.takeException(), isNull, reason: 'a menu callback must not leak an unhandled async refusal');
      if (scenario.linux || scenario.up) {
        expect(commands, isEmpty, reason: 'a refused probe or unsupported preparation must not start sudo');
        final problem = find.byKey(const Key('vpn-problem'));
        expect(problem, findsOneWidget, reason: 'the refusal needs its own place before the action ends');
        expect(
          tester.widget<Text>(problem).data,
          scenario.linux ? probeRefusal : 'The VPN needs XDG_RUNTIME_DIR owned by this user with permissions 0700.',
          reason: 'platforms without Linux probes must retain the existing preparation refusal',
        );
        expect(result, isNull, reason: 'the refusal remains open until dismissed');
        await tester.tap(find.text('Close'));
      } else {
        expect(commands, [
          hostVpnDownCommand(host: 'demo', networkNumber: 0, interface: 'porelo-0'),
        ], reason: 'taking the VPN down must keep the command offered before Linux state probing');
        terminal.endsWith(0);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
      }
      await World.settle(tester);
      expect(probes, scenario.linux ? 1 : 0, reason: 'only Linux actions may depend on ip being installed');
      expect(result, isFalse, reason: 'each action must complete safely without claiming a fresh handshake');
    }
  });

  for (final ending in ['success', 'failure', 'cancelled sudo', 'closed dialog', 'exception']) {
    // Harm: a private WireGuard key left after any terminal ending can be read or reused later.
    testWidgets('the private VPN file is removed after $ending', (tester) async {
      final scratch = (await tester.runAsync(() => Directory.systemTemp.createTemp('vpn-lifetime-')))!;
      addTearDown(() => scratch.delete(recursive: true));
      final source = File('${scratch.path}/porelo.conf');
      await tester.runAsync(() => source.writeAsString('invented-private-key'));
      final settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      await settings.rememberHostUp('demo', _record.withVpnFile(source.path));
      final commands = <List<String>>[];
      final terminal = FakeTerminal([]);
      await open(tester, settings, commands, terminal, throwsOnOpen: ending == 'exception');
      expect(commands, hasLength(1));
      final usedFile = File(commands.single.lastWhere((arg) => arg.endsWith('/porelo.conf')));
      if (ending == 'closed dialog') {
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      } else if (ending != 'exception') {
        terminal.endsWith(switch (ending) {
          'success' => 0,
          'cancelled sudo' => 1,
          _ => 2,
        });
      }
      await World.settle(tester);
      if (find.byKey(const Key('unlock-done')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
      }
      for (var turn = 0; turn < 30; turn++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await World.settle(tester);
        if (!(await tester.runAsync(usedFile.exists))!) break;
      }
      expect(await tester.runAsync(usedFile.exists), isFalse, reason: '$ending must remove the private configuration');
    }, skip: _notLinux);
  }

  Future<void> openSaveMenu(
    WidgetTester tester,
    Settings settings, {
    required HostTunnel? tunnel,
    String address = '203.0.113.8',
    required SecretStore secrets,
    required Future<String?> Function() saveTunnel,
    required ValueChanged<Future<void>> exporting,
    HostFiles Function(SecretStore)? hostFiles,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => CommandMenu(
              tooltip: 'Server commands',
              commands: hostMachineCommands(
                machine: _machine,
                settings: settings,
                takeDown: () {},
                bringVpnUp: () {},
                saveTunnel: () => exporting(
                  saveHostTunnel(
                    context,
                    project: _machine.hostProject,
                    tunnel: tunnel,
                    address: address,
                    settings: settings,
                    secretStore: secrets,
                    hostFiles: hostFiles,
                    saveTunnel: saveTunnel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Server commands'));
    await World.settle(tester);
  }

  for (final restarted in [false, true]) {
    for (final alreadySaved in [false, true]) {
      // Harm: closing setup must not strand the server without a usable VPN file or keep an obsolete path.
      testWidgets('the server menu saves the VPN after restart $restarted with an earlier save $alreadySaved', (
        tester,
      ) async {
        final scratch = await tester.runAsync(() => Directory.systemTemp.createTemp('host-vpn-save-'));
        addTearDown(() => scratch!.delete(recursive: true));
        final store = MemorySettingsStore();
        var settings = Settings(store);
        addTearDown(settings.dispose);
        final secrets = _TunnelSecrets({HostFiles.keyName('demo'): base64Encode(List<int>.filled(32, 7))});
        final peer = await HostFiles.publicKey(secrets.values[HostFiles.keyName('demo')]!);
        final host = await HostFiles.publicKey(base64Encode(List<int>.filled(32, 9)));
        final tunnel = HostTunnel(hostPublicKey: host, peerPublicKey: peer);
        final record = HostUpRecord.fromStored({..._record.stored, 'vpnPeerPublicKey': peer})!
            .withTunnel(hostPublicKey: host, address: '203.0.113.8');
        await settings.rememberHostUp('demo', record.withVpnFile(alreadySaved ? '/previous.conf' : null));
        if (restarted) {
          settings = Settings(store);
          addTearDown(settings.dispose);
          await settings.load();
        }
        final paths = [
          for (final name in ['first.conf', 'next.conf']) '${scratch!.path}/$name',
        ];
        final choices = List<String>.of(paths);
        final files = _PendingTunnelFiles(secrets);
        await openSaveMenu(
          tester,
          settings,
          tunnel: restarted ? null : tunnel,
          address: restarted ? '' : '203.0.113.8',
          secrets: secrets,
          saveTunnel: () async => choices.removeAt(0),
          exporting: unawaited,
          hostFiles: (_) => files,
        );
        expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.vpnUp'))).enabled, isTrue);
        for (final path in paths) {
          final save = find.byKey(const Key('machine.saveTunnel'));
          expect(tester.widget<PopupMenuItem<String>>(save).enabled, isTrue);
          await tester.tap(save);
          await World.settle(tester);
          await tester.runAsync(files.complete);
          await World.settle(tester);
          final contents = await tester.runAsync(() => File(path).readAsString());
          expect(contents, contains('PublicKey = $host'));
          expect(contents, contains('Endpoint = 203.0.113.8:51820'));
          expect(settings.hostUp('demo')!.vpnFile, path, reason: 'only a completed export may replace the kept path');
          await tester.tap(find.byTooltip('Server commands'));
          await World.settle(tester);
          expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.vpnUp'))).enabled, isTrue);
        }
        expect(choices, isEmpty, reason: 'each save asks for its own destination');
      });
    }
  }

  for (final refusal in ['path', 'settings', 'file', 'store']) {
    // Harm: an export refusal must be visible and must not replace the last usable VPN path.
    testWidgets('the server menu shows a VPN export refusal for $refusal and keeps the old path', (tester) async {
      final settings = Settings(MemorySettingsStore());
      addTearDown(settings.dispose);
      await settings.rememberHostUp('demo', _record.withVpnFile('/previous.conf'));
      final secrets = _TunnelSecrets({});
      // A path this platform's save check accepts, so each case reaches its own refusal.
      final chosen = Platform.isWindows ? r'C:\private\chosen.conf' : '/private/chosen.conf';
      final expected = switch (refusal) {
        'path' => 'The saved VPN file needs a plain absolute path',
        'settings' => 'Use Put this project on a server… again.',
        'file' => 'Cannot save the tunnel file: $chosen.',
        _ => 'The system secret store could not read the WireGuard key.',
      };
      await openSaveMenu(
        tester,
        settings,
        tunnel: refusal == 'settings'
            ? null
            : const HostTunnel(hostPublicKey: 'host-public', peerPublicKey: 'peer-public'),
        secrets: secrets,
        saveTunnel: () async => refusal == 'path' ? 'relative.conf' : chosen,
        exporting: unawaited,
        hostFiles: (store) => _RefusingTunnelFiles(
          store,
          refusal == 'file'
              ? FileSystemException('invented detail that must not appear', chosen)
              : const SecretStoreFailed('invented detail that must not appear'),
        ),
      );
      await tester.tap(find.byKey(const Key('machine.saveTunnel')));
      await World.settle(tester);
      expect(find.byKey(const Key('vpn-problem')), findsOneWidget);
      expect(find.textContaining(expected), findsOneWidget);
      expect(find.textContaining('invented detail'), findsNothing);
      expect(settings.hostUp('demo')!.vpnFile, '/previous.conf');
      await tester.tap(find.text('Close'));
      await World.settle(tester);
    });
  }

  // Harm: offering export without a kept host record cannot retain the file needed for VPN installation.
  test('saving the VPN is unavailable without a kept host record', () {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final command = hostMachineCommands(
      machine: _machine,
      settings: settings,
      takeDown: () {},
      saveTunnel: () {},
    ).singleWhere((each) => each.id == 'machine.saveTunnel');
    expect(command.home, Home.machineMenu);
    expect(command.available, isFalse);
    expect(command.unavailable, isNotEmpty);
  });

  // Harm: a terminal exit zero without a fresh expected handshake must not finish setup.
  testWidgets('exit zero without a handshake receipt leaves VPN setup unverified', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final terminal = FakeTerminal([]);
    final commands = <List<String>>[];
    await open(tester, settings, commands, terminal, receipt: false);
    final usedFile = File(commands.single.firstWhere((arg) => arg.endsWith('/porelo.conf')));
    terminal.endsWith(0);
    for (var turn = 0; turn < 30; turn++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
      if (!(await tester.runAsync(usedFile.exists))!) break;
    }
    await World.settle(tester);
    expect(
      find.byKey(const Key('unlock-terminal')),
      findsOneWidget,
      reason: 'exit zero alone cannot close the verified setup',
    );
    await tester.tap(find.byKey(const Key('unlock-done')));
    await World.settle(tester);
  }, skip: _notLinux);

  // Harm: under a snap's AppArmor label wg-quick cannot run, so a sudo terminal fails and leaves no word of why.
  testWidgets('a VPN step under a snap is refused before sudo, saying how to start outside it', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    await open(tester, settings, commands, FakeTerminal([]), confinement: 'snap.flutter.flutter (complain)');
    await World.settle(tester);
    expect(commands, isEmpty, reason: 'no root command is opened under the snap');
    expect(
      tester.widget<Text>(find.byKey(const Key('vpn-problem'))).data,
      contains('snap.flutter.flutter'),
      reason: 'the refusal names the label it runs under',
    );
  }, skip: _notLinux);

  // Harm: the root step's fail line was shown only in the terminal, and gone once it was closed.
  testWidgets('the root step\'s fail line is handed on when the VPN is not confirmed', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final terminal = FakeTerminal([]);
    final said = <String>[];
    await open(tester, settings, <List<String>>[], terminal, receipt: false, failed: said.add);
    // As the root step ends on its fail line: the terminal's last words, read when the command has ended.
    terminal.prints('[sudo] password for someone:\r\nThe VPN could not be brought up: invented wg-quick words\r\n');
    await World.settle(tester);
    terminal.endsWith(1);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('unlock-done')));
    for (var turn = 0; turn < 30 && said.isEmpty; turn++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(said, ['The VPN could not be brought up: invented wg-quick words']);
  }, skip: _notLinux);

  // Harm: a verified finish closes the cancel confirmation instead of the terminal, so the VPN terminal stays open and setup does not go on.
  testWidgets('a verified finish closes the terminal and the confirmation above it', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final terminal = FakeTerminal([]);
    await open(tester, settings, <List<String>>[], terminal);
    await tester.tap(find.byKey(const Key('unlock-cancel')));
    await World.settle(tester);
    expect(find.byKey(const Key('unlock-cancel-yes')), findsOneWidget, reason: 'the confirmation is on top');
    terminal.endsWith(0);
    for (var turn = 0; turn < 30 && find.byKey(const Key('unlock-terminal')).evaluate().isNotEmpty; turn++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await World.settle(tester);
    }
    expect(find.byKey(const Key('unlock-terminal')), findsNothing, reason: 'the verified terminal closes itself');
    expect(find.byKey(const Key('unlock-cancel-yes')), findsNothing, reason: 'its confirmation goes with it');
  }, skip: _notLinux);

  // Harm: a rented host's tasks that never reach the room on this laptop once its VPN is up, or the line this laptop
  // needs for the same name left unsaid.
  for (final (verified, serverOnly) in [(true, false), (false, false), (true, true)]) {
    testWidgets(
      serverOnly
          ? 'server-only VPN never publishes this account homeserver'
          : 'project preparation publishes its homeserver only after verification (verified $verified)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = Settings(MemorySettingsStore());
        addTearDown(settings.dispose);
        final scratch = (await tester.runAsync(() => Directory.systemTemp.createTemp('vpn-homeserver-')))!;
        addTearDown(() => scratch.delete(recursive: true));
        final runtime = Directory('${scratch.path}/runtime')..createSync();
        await tester.runAsync(() => Process.run('chmod', ['700', runtime.path]));
        File('${scratch.path}/porelo/matrix/homeserver.conf')
          ..createSync(recursive: true)
          ..writeAsStringSync('PORELO_MATRIX_PORT=8008\n');
        final hosts = File('${scratch.path}/hosts')..writeAsStringSync('127.0.0.1 localhost\n');
        final published = <List<String>>[];
        final answered = Completer<void>();
        final private = base64Encode(List<int>.filled(32, 7));
        final peer = await HostFiles.publicKey(private);
        final host = await HostFiles.publicKey(base64Encode(List<int>.filled(32, 9)));
        final record = HostUpRecord.fromStored({
          ..._record.stored,
          'vpnPeerPublicKey': peer,
          if (serverOnly) ...{'host': 'demo', 'hostName': 'demo'},
        })!.withTunnel(hostPublicKey: host, address: '203.0.113.8');
        final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
        addTearDown(machines.dispose);
        final runs = HostRuns(
          machines,
          endpointFor: (_) => '/tmp/prepared.sock',
          probeLink: () async => true,
          ping: () async => true,
          homeserver: HomeserverPublishing(
            configuration: '${scratch.path}/porelo',
            hostsFile: hosts.path,
            run: (_, arguments) async {
              published.add(arguments);
              // Held open until the test has seen the VPN's own outcome come first.
              await answered.future;
              return ProcessResult(0, 0, '{"published": "10.73.0.2:8008", "name": "matrix.porelo.internal"}\n', '');
            },
          ),
        );
        addTearDown(runs.dispose);
        final process = HostProcess();
        final run = runs.start(
          project: 'demo',
          session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
          record: record,
          settings: settings,
        );
        process.line(
          const Step(
            'up',
            StepState.done,
            address: '203.0.113.7',
            account: 'worker',
            socket: '/run/user/1007/porelo/porelod.sock',
          ),
        );
        if (serverOnly) {
          process.raw(
            jsonEncode({
              'v': 1,
              'state': 'host',
              'host': {
                'address': '203.0.113.7',
                'endpoint': '203.0.113.7:51820',
                'wireguard_public_key': host,
                'network': '10.73.0.0/24',
                'ssh_host_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
                'ca_sha256': 'a' * 64,
                'homeserver': 'matrix.demo.porelo.internal',
              },
            }),
          );
        }
        process.end(0);
        await tester.runAsync(() => run.finished);
        expect(run.awaitingVpn, isTrue);
        final terminal = FakeTerminal([]);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  openPreparationVpn(
                    context,
                    run: run,
                    runs: runs,
                    settings: settings,
                    secretStore: _TunnelSecrets({HostFiles.keyName('demo'): private}),
                    environment: {'XDG_RUNTIME_DIR': runtime.path},
                    confinement: () => null,
                    open: (executable, arguments, {int columns = 80, int rows = 24}) {
                      final source = arguments.firstWhere((arg) => arg.endsWith('/porelo.conf'));
                      // The receipt of a fresh handshake, after the attempt started; none where the server never answered.
                      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 5;
                      if (verified) File('$source.checked').writeAsStringSync('$host\t$now\t${now + 1}\n');
                      return terminal;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        for (var turn = 0; turn < 100 && find.byKey(const Key('unlock-terminal')).evaluate().isEmpty; turn++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await World.settle(tester);
        }
        expect(published, isEmpty, reason: 'nothing is published before the handshake is seen');
        terminal.endsWith(0);
        for (var turn = 0; turn < 100 && verified && (serverOnly ? !run.ready : published.isEmpty); turn++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await World.settle(tester);
        }
        if (verified) {
          expect(run.vpnOpen, isFalse, reason: 'the VPN\'s own outcome waits on neither the transport nor its dialog');
          expect(run.ready, isTrue, reason: 'the server is reachable before the homeserver is published');
        }
        answered.complete();
        for (var turn = 0; turn < 100 && find.byKey(const Key('homeserver-published')).evaluate().isEmpty; turn++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await World.settle(tester);
          if (!verified && find.byKey(const Key('unlock-done')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const Key('unlock-done')));
          }
        }
        if (!verified || serverOnly) {
          expect(published, isEmpty, reason: 'only a verified project setup may publish this account homeserver');
          expect(find.byKey(const Key('homeserver-published')), findsNothing);
          return;
        }
        expect(published.single, ['publish', '--address', '10.73.0.2:8008', '--name', 'matrix.porelo.internal']);
        expect(find.textContaining('https://matrix.porelo.internal:8008'), findsOneWidget);
        expect(
          tester.widget<SelectableText>(find.byKey(const Key('homeserver-laptop-line'))).data,
          "grep -qxF '127.0.0.1 matrix.porelo.internal # porelo-matrix' /etc/hosts || "
          "echo '127.0.0.1 matrix.porelo.internal # porelo-matrix' | sudo tee -a /etc/hosts",
          reason: 'the laptop lacks the line, so the one command that adds it is given to copy and run',
        );
      },
      skip: _notLinux,
    );
  }

  // Harm: a copied command that adds the line twice, or that does not run as it is copied.
  test('the laptop\'s command adds its line once, and leaves a file that has it as it is', () async {
    final folder = await Directory.systemTemp.createTemp('porelo-hosts-');
    addTearDown(() => folder.delete(recursive: true));
    // A commented line and one for another address must not count as the line.
    final hosts = File(
      '${folder.path}/hosts',
    )..writeAsStringSync('127.0.0.1 localhost\n# 127.0.0.1 matrix.porelo.internal\n10.73.0.2 matrix.porelo.internal\n');
    // As the person runs it, but on a file of the test's own and without sudo.
    final command = HomeserverPublishing.laptopCommand
        .replaceAll('/etc/hosts', hosts.path)
        .replaceAll('sudo tee', 'tee');
    for (var run = 0; run < 2; run++) {
      final result = await Process.run('/bin/sh', ['-c', command]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    expect(hosts.readAsLinesSync(), [
      '127.0.0.1 localhost',
      '# 127.0.0.1 matrix.porelo.internal',
      '10.73.0.2 matrix.porelo.internal',
      HomeserverPublishing.laptopLine,
    ]);
  }, skip: _notLinux);

  // Harm: a person told to edit /etc/hosts for a line they have, or for a homeserver that was not published.
  for (final (published, missing) in [(true, false), (false, true)]) {
    testWidgets(
      'the laptop\'s line is given only where it is missing and something was published ($published, $missing)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  showHomeserverPublished(
                    context,
                    PublishOutcome(published: published, words: published ? 'published' : 'refused'),
                    laptopLineMissing: missing,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('homeserver-published')), findsOneWidget);
        expect(find.byKey(const Key('homeserver-laptop-line')), findsNothing);
        await tester.tap(find.byKey(const Key('homeserver-published-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('homeserver-published')), findsNothing, reason: 'Close closes it');
      },
    );
  }

  // Harm: exposing the WireGuard private key in process arguments leaks it to other processes.
  testWidgets('the private VPN key is absent from every argument and the displayed command', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    await open(tester, settings, commands, FakeTerminal([]));
    final private = base64Encode(List<int>.filled(32, 7));
    expect(commands, hasLength(1));
    expect(
      commands.single.any((argument) => argument.contains(private)),
      isFalse,
      reason: 'no argument carries the private key',
    );
    expect(tester.widget<SelectableText>(find.byKey(const Key('unlock-command'))).data!.contains(private), isFalse);
  }, skip: _notLinux);

  // Harm: the forge's CA kept here and never given to the root step, or given as a file the person could swap.
  testWidgets('a kept forge CA reaches the root step as its argument, and none is given without one', (tester) async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final ca =
        '-----BEGIN CERTIFICATE-----\n${base64Encode(List<int>.generate(48, (i) => i))}\n-----END CERTIFICATE-----\n';
    final without = <List<String>>[];
    await open(tester, settings, without, FakeTerminal([]));
    expect(without.single.last, isEmpty, reason: 'nothing of it without a CA');
    await tester.pumpWidget(const SizedBox.shrink());
    await settings.rememberForgeCa('demo', ca);
    final commands = <List<String>>[];
    await open(tester, settings, commands, FakeTerminal([]));
    expect(commands.single.last, ca.trimRight(), reason: 'the certificate itself, public, read by root from no file');
  }, skip: _notLinux);

  // Harm: a teardown action must not run installation or target the remote server.
  testWidgets('VPN down runs only wg-quick locally without needing a saved file', (tester) async {
    final commands = <List<String>>[];
    await open(tester, Settings(MemorySettingsStore()), commands, FakeTerminal([]), up: false);
    expect(commands, [hostVpnDownCommand(host: 'demo', networkNumber: 0, interface: 'porelo-0')]);
  });
}

class _TunnelSecrets implements SecretStore {
  _TunnelSecrets(this.values);
  final Map<String, String> values;
  int reads = 0;

  @override
  Future<String?> read(String name) async {
    reads++;
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async => values[name] = value;

  @override
  Future<void> remove(String name) async => values.remove(name);

  @override
  Future<void> close() async => fail('An injected store must remain open for its owner.');
}

class _RefusingTunnelFiles extends HostFiles {
  _RefusingTunnelFiles(super.store, this.refusal);
  final Exception refusal;

  @override
  Future<void> exportTunnel({
    required String project,
    required HostTunnel tunnel,
    required String address,
    required File destination,
    int networkNumber = 0,
    String? peerAddress,
  }) async => throw refusal;
}

class _PendingTunnelFiles extends HostFiles {
  _PendingTunnelFiles(super.store);
  late Future<void> Function() _pending;

  Future<void> complete() => _pending();

  @override
  Future<void> exportTunnel({
    required String project,
    required HostTunnel tunnel,
    required String address,
    required File destination,
    int networkNumber = 0,
    String? peerAddress,
  }) {
    final answer = Completer<void>();
    _pending = () async {
      try {
        await super.exportTunnel(
          project: project,
          tunnel: tunnel,
          address: address,
          destination: destination,
          networkNumber: networkNumber,
          peerAddress: peerAddress,
        );
        answer.complete();
      } catch (error, stack) {
        answer.completeError(error, stack);
      }
    };
    return answer.future;
  }
}
