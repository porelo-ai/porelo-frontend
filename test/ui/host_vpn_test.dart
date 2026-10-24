import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_vpn_dialog.dart';

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
    expect(command.unavailable, 'save the VPN connection to this server first');
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
