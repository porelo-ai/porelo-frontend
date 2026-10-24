import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_vpn_dialog.dart';
import 'package:porelo_frontend/src/ui/host_tunnel_export.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';

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

void main() {
  Future<void> open(
    WidgetTester tester,
    Settings settings,
    List<List<String>> commands,
    FakeTerminal terminal, {
    bool up = true,
    Future<void> Function(String file)? deleteSavedFile,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
                deleteSavedFile: deleteSavedFile ?? (_) async => fail('No saved file may be deleted without consent.'),
                open: (executable, arguments, {int columns = 80, int rows = 24}) {
                  commands.add([executable, ...arguments]);
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
    await World.settle(tester);
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
        expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.vpnUp'))).enabled, alreadySaved);
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

  for (final path in [
    "/tmp/a'b.conf",
    '/tmp/a"b.conf',
    '-file',
    r'/tmp/$file',
    '/tmp/a\nb',
    'relative.conf',
    '/tmp/a\x00b',
    '/tmp/a;b',
    '/tmp/`id`',
    '/tmp/a\\b',
  ]) {
    // Harm: a saved path must never change a command running as root.
    testWidgets('an unsafe saved VPN path ${path.codeUnits} opens no terminal', (tester) async {
      final settings = Settings(MemorySettingsStore());
      await settings.rememberHostUp('demo', _record.withVpnFile(path));
      final commands = <List<String>>[];
      await open(tester, settings, commands, FakeTerminal([]));
      expect(commands, isEmpty, reason: 'invalid paths must be refused before opening a root command');
      expect(find.byKey(const Key('vpn-problem')), findsOneWidget);
      expect(find.byKey(const Key('unlock-terminal')), findsNothing);
    });
  }

  // Harm: attempting installation without the chosen source can run the wrong root command.
  test('VPN bring-up without an exported file is unavailable with its reason', () async {
    final settings = Settings(MemorySettingsStore());
    await settings.rememberHostUp('demo', _record);
    final command = hostMachineCommands(
      machine: _machine,
      settings: settings,
      takeDown: () {},
      bringVpnUp: () {},
    ).singleWhere((each) => each.id == 'machine.vpnUp');
    expect(command.home, Home.machineMenu);
    expect(command.available, isFalse);
    expect(command.unavailable, 'use Save the VPN connection… first');
  });

  // Harm: shell splitting can install a different file as root.
  testWidgets('VPN bring-up passes the saved path as one positional argument', (tester) async {
    final settings = Settings(MemorySettingsStore());
    const path = '/tmp/private folder/porelo.conf';
    await settings.rememberHostUp('demo', _record.withVpnFile(path));
    final commands = <List<String>>[];
    await open(tester, settings, commands, FakeTerminal([]));
    expect(commands, [
      [
        '/bin/sh',
        '-c',
        r'sudo install -m 600 "$1" /etc/wireguard/porelo.conf && sudo wg-quick up porelo',
        'porelo-vpn',
        path,
      ],
    ]);
    expect(tester.widget<SelectableText>(find.byKey(const Key('unlock-command'))).data, contains("'$path'"));
  });

  for (final code in [0, 1, 129]) {
    for (final delete in [false, true]) {
      // Harm: deleting before successful installation or without consent loses the private key file.
      testWidgets('VPN exit $code offers deletion only after success and deletes only with consent $delete', (
        tester,
      ) async {
        const file = '/private/saved.conf';
        final files = {file};
        final deleted = <String>[];
        final settings = Settings(MemorySettingsStore());
        await settings.rememberHostUp('demo', _record.withVpnFile(file));
        final terminal = FakeTerminal([]);
        final commands = <List<String>>[];
        await open(
          tester,
          settings,
          commands,
          terminal,
          deleteSavedFile: (file) async {
            deleted.add(file);
            expect(files.remove(file), isTrue, reason: 'only the saved copy may be deleted');
          },
        );
        expect(commands, hasLength(1), reason: 'the session must use the injected fake terminal');
        expect(find.byKey(const Key('vpn-delete')), findsNothing);
        terminal.endsWith(code);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
        expect(files, contains(file), reason: 'success alone never consents to deletion');
        expect(deleted, isEmpty);
        expect(settings.hostUp('demo')!.vpnFile, file, reason: 'no saved path is forgotten before confirmed deletion');
        if (code != 0) {
          expect(find.byKey(const Key('vpn-delete')), findsNothing);
          return;
        }
        expect(find.byKey(const Key('vpn-delete')), findsOneWidget);
        await tester.tap(find.byKey(Key(delete ? 'vpn-delete' : 'vpn-keep')));
        await World.settle(tester);
        expect(files.contains(file), !delete);
        expect(deleted, delete ? [file] : isEmpty);
        expect(settings.hostUp('demo')!.vpnFile, delete ? null : file);
        expect(find.byKey(const Key('vpn-delete')), findsNothing, reason: 'the offer is made once for this run');
      });
    }
  }

  // Harm: a teardown action must not run installation or target the remote server.
  testWidgets('VPN down runs only wg-quick locally without needing a saved file', (tester) async {
    final commands = <List<String>>[];
    await open(tester, Settings(MemorySettingsStore()), commands, FakeTerminal([]), up: false);
    expect(commands, [
      ['sudo', 'wg-quick', 'down', 'porelo'],
    ]);
  });
}

class _TunnelSecrets implements SecretStore {
  _TunnelSecrets(this.values);
  final Map<String, String> values;

  @override
  Future<String?> read(String name) async => values[name];

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
  }) {
    final answer = Completer<void>();
    _pending = () async {
      try {
        await super.exportTunnel(project: project, tunnel: tunnel, address: address, destination: destination);
        answer.complete();
      } catch (error, stack) {
        answer.completeError(error, stack);
      }
    };
    return answer.future;
  }
}
