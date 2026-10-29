// Removal executes bash with SSH and keepassxc-cli stand-ins made executable with chmod.
@Tags(['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/host_admin_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_admin.dart';

Future<int> _executeRemoval(
  FakeTerminal terminal,
  Directory scratch, {
  required int code,
  required String refusal,
}) async {
  final cli = File('${scratch.path}/keepassxc');
  final ssh = File('${scratch.path}/ssh');
  cli.writeAsStringSync('''#!/usr/bin/python3 -I
import os, sys
master = sys.stdin.readline().rstrip('\\n')
if master != 'fixture-master': sys.exit(1)
if sys.argv[1] == 'ls': print('shared/')
else: print(os.environ['FIXTURE_TOKEN'])
''');
  ssh.writeAsStringSync('''#!/usr/bin/python3 -I
import json, os, pathlib, sys
assert sys.stdin.read() == os.environ['FIXTURE_TOKEN'] + '\\n'
pathlib.Path(os.environ['FIXTURE_MARKER']).write_text('called')
code = int(os.environ['FIXTURE_EXIT'])
if code: sys.stderr.write(os.environ['FIXTURE_REFUSAL'])
else: print(json.dumps({'project': sys.argv[-1].split()[-1], 'removed': True, 'locked': []}))
sys.exit(code)
''');
  for (final file in [cli, ssh]) {
    expect((await Process.run('/usr/bin/chmod', ['700', file.path])).exitCode, 0);
  }
  final command = List<String>.of(terminal.command);
  command[command.length - 1] = command.last
      .replaceAll('/usr/bin/keepassxc-cli', cli.path)
      .replaceAll('/usr/bin/ssh', ssh.path);
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    environment: {
      'FIXTURE_TOKEN': 'fixture-central',
      'FIXTURE_EXIT': '$code',
      'FIXTURE_REFUSAL': refusal,
      'FIXTURE_MARKER': '${scratch.path}/ssh-called',
    },
  );
  process.stdin.writeln(code == 1 ? 'wrong\nwrong\nwrong' : 'fixture-master');
  await process.stdin.close();
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final result = await process.exitCode;
  expect('${await output}${await errors}', isNot(contains('fixture-central')));
  expect(File('${scratch.path}/ssh-called').existsSync(), code != 1);
  return result;
}

void main() {
  tearDown(() => roles = const Roles());

  // Harm: project administration alone must not authorize a root project removal.
  test('taking a project off requires the host admin role and a host record', () {
    roles = Roles.fromArguments(['--roles', 'project-admin']);
    final ordinary = takeProjectOffServerCommand('demo', run: () {});
    expect(ordinary.role, Role.hostAdmin);
    expect(ordinary.available, isFalse);
    expect(ordinary.unavailable, contains('the host admin takes it off from the server’s menu'));
    roles = Roles.fromArguments(['--roles', 'host-admin']);
    expect(
      takeProjectOffServerCommand('demo').unavailable,
      contains('the host admin takes it off from the server’s menu'),
    );
    expect(takeProjectOffServerCommand('demo', run: () {}).available, isTrue);
  });

  // Harm: a root removal racing the server's own setup playbook or its stop.
  test('taking a project off waits while its server’s setup is under way', () {
    roles = Roles.fromArguments(['--roles', 'host-admin']);
    const busy = 'its server’s setup is under way; see its protocol';
    final held = takeProjectOffServerCommand('demo', run: () {}, busy: busy);
    expect(held.available, isFalse);
    expect(held.unavailable, busy);
  });

  // Harm: holding another server's record must never enable removal on the project's host.
  for (final (held, code) in [(false, 0), (true, 65), (true, 0)]) {
    testWidgets('the project menu selects its associated host record (held: $held, helper: $code)', (tester) async {
      final scratch = Directory.systemTemp.createTempSync('project-menu-removal-');
      final wasDesk = desk;
      desk = Desk.of('linux', {...desk.environment, 'XDG_STATE_HOME': '${scratch.path}/state'});
      addTearDown(() async {
        desk = wasDesk;
        await tester.runAsync(() => scratch.delete(recursive: true));
      });
      roles = Roles.fromArguments(['--roles', 'host-admin']);
      await World.startBackend(World.work);
      await World.startApp(tester);
      HostUpRecord record(String name, int network) => HostUpRecord(
        host: name,
        hostName: name,
        vpnNetworkNumber: network,
        vpnInterface: 'porelo-$network',
        preparedHost: PreparedHost.read({
          ...hostValues(),
          'network': '10.73.$network.0/24',
          'address': '203.0.113.$network',
          'endpoint': '203.0.113.$network:51820',
          'homeserver': 'matrix.$name.porelo.internal',
        }),
        scalewayProject: 'fixture',
        account: 'root',
        tresor: '',
        folder: null,
        signingKey: '',
        identity: '/keys/$name',
        publicKey: '/keys/$name.pub',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      );
      await World.settings.rememberHostUp('garden', record('garden', 8));
      if (held) await World.settings.rememberHostUp('orchard', record('orchard', 7));
      await World.settings.rememberProjectHost('checkout', 'orchard');
      final secrets = File('${scratch.path}/secrets.kdbx')..writeAsStringSync('encrypted fixture');
      await World.settings.rememberSecretsFile(secrets.path);
      World.fleet.selectProject('checkout');
      World.shell.goTo(Section.project);
      await World.settle(tester);
      await World.tapInView(tester, 'project-menu');
      final entry = find.byKey(const Key('project.takeOffServer'));
      expect(tester.widget<PopupMenuItem<String>>(entry).enabled, held);
      if (held) {
        await World.tapInView(tester, 'project.takeOffServer');
        await World.settle(tester);
        final dialog = tester.widget<HostAdminDialog>(find.byType(HostAdminDialog));
        expect(dialog.host.vpnAddress, '10.73.7.1', reason: 'the first, unrelated host record must not be used');
        expect(dialog.action, 'remove');
        expect(dialog.project, 'checkout');
        await tester.tap(find.byKey(const Key('wizard-next')));
        await World.settle(tester);
        final start = tester.widget<FilledButton>(find.byKey(const Key('wizard-start'))).onPressed!;
        late Future<void> running;
        await tester.runAsync(() async {
          running = Function.apply(start, const []) as Future<void>;
          for (var count = 0; count < 100 && World.terminals.isEmpty; count++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await World.settle(tester);
        expect(World.terminals, hasLength(1));
        final terminal = World.terminals.single;
        const refusal = 'porelo-host-project: unpushed work stays on the host.';
        final result = await tester.runAsync(() => _executeRemoval(terminal, scratch, code: code, refusal: refusal));
        terminal.endsWith(result!);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
        await tester.runAsync(() => running);
        await World.settle(tester);
        expect(World.backend.deletions, isEmpty, reason: 'taking a project off the host does not unfollow it');
        expect(
          World.settings.projectHost('checkout'),
          code == 0 ? isNull : 'orchard',
          reason: 'only confirmed removal clears the saved association',
        );
        if (code == 65) expect(find.textContaining(refusal), findsWidgets);
        await World.restartApp(tester);
        expect(
          World.settings.projectHost('checkout'),
          code == 0 ? isNull : 'orchard',
          reason: 'the confirmed association change survives restart',
        );
      } else {
        expect(find.textContaining('Unavailable: the host admin takes it off from the server’s menu'), findsOneWidget);
      }
    });
  }

  // Harm: losing a helper refusal or treating it as success can hide unpushed work.
  for (final code in [65, 73, 69, 64, 0, 1, 127]) {
    testWidgets('project removal keeps the helper verdict for exit $code', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      roles = Roles.fromArguments(['--roles', 'host-admin']);
      final scratch = Directory.systemTemp.createTempSync('project-take-off-');
      File('${scratch.path}/secrets.kdbx').writeAsStringSync('encrypted fixture');
      addTearDown(() => tester.runAsync(() => scratch.delete(recursive: true)));
      final record = HostUpRecord(
        host: 'orchard',
        hostName: 'orchard',
        vpnNetworkNumber: 7,
        vpnInterface: 'porelo-7',
        preparedHost: PreparedHost.read(hostValues()),
        scalewayProject: 'fixture',
        account: 'root',
        tresor: '',
        folder: null,
        signingKey: '',
        identity: '${scratch.path}/rental',
        publicKey: '${scratch.path}/rental.pub',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      );
      FakeTerminal? terminal;
      final refusal = switch (code) {
        65 => 'porelo-host-project: api has commits nowhere on its central forge.\n',
        73 => 'porelo-host-project: the check could not finish.\n',
        69 => 'porelo-host-project: not ready.\n',
        64 => 'porelo-host-project: usage: remove project.\n',
        _ => '',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => takeProjectOffServerCommand(
                  'demo',
                  run: () => unawaited(
                    openHostAdminDialog(
                      context,
                      record: record,
                      action: 'remove',
                      project: 'demo',
                      secretsFile: '${scratch.path}/secrets.kdbx',
                      environment: {'XDG_STATE_HOME': '${scratch.path}/state'},
                      openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                        return terminal = FakeTerminal([program, ...arguments]);
                      },
                    ),
                  ),
                ).run(),
                child: const Text('Take project off'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Take project off'));
      await World.settle(tester);
      final name = tester.widget<TextField>(find.byKey(const Key('host-admin-name')));
      expect(name.controller!.text, 'demo');
      expect(name.readOnly, isTrue, reason: 'this action must remove the project whose menu was opened');
      await tester.tap(find.byKey(const Key('wizard-next')));
      await World.settle(tester);
      final start = tester.widget<FilledButton>(find.byKey(const Key('wizard-start'))).onPressed!;
      late Future<void> running;
      await tester.runAsync(() async {
        running = Function.apply(start, const []) as Future<void>;
        for (var count = 0; count < 100 && terminal == null; count++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await World.settle(tester);
      expect(terminal, isNotNull);
      expect(terminal!.command.last, contains('root@10.73.7.1'));
      expect(terminal!.command.last, contains(record.identity));
      expect(terminal!.command.last, contains('porelo-host-project remove demo'));
      final exitCode = code == 127
          ? 127
          : await tester.runAsync(() => _executeRemoval(terminal!, scratch, code: code, refusal: refusal));
      terminal!.endsWith(exitCode!);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      await tester.runAsync(() => running);
      await World.settle(tester);
      final action = tester.widget<Wizard>(find.byType(Wizard)).actionSteps.single;
      expect(action.state(), code != 0 ? WizardActionState.refused : WizardActionState.done);
      if (code == 1 || code == 127) {
        final words = tester.widget<SelectableText>(find.byKey(const Key('host-admin-refusal'))).data!;
        expect(words, isNot(contains('porelo-project-removal-')));
        expect(words, contains(code == 1 ? 'did not open with that password' : 'local'));
      } else if (code != 0) {
        expect(tester.widget<SelectableText>(find.byKey(const Key('host-admin-refusal'))).data, refusal);
      } else {
        expect(find.byKey(const Key('host-admin-answer')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
