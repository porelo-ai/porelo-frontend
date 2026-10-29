import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/host_admin_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_admin.dart';

void main() {
  tearDown(() => roles = const Roles());

  // Harm: project administration alone must not authorize a root project removal.
  test('taking a project off requires the host admin role and a host record', () {
    roles = Roles.fromArguments(['--roles', 'project-admin']);
    final ordinary = takeProjectOffServerCommand('demo', run: () {});
    expect(ordinary.role, Role.hostAdmin);
    expect(ordinary.available, isFalse);
    expect(ordinary.unavailable, 'the host admin takes a project off its server');
    roles = Roles.fromArguments(['--roles', 'host-admin']);
    expect(takeProjectOffServerCommand('demo').unavailable, 'the host admin takes a project off its server');
    expect(takeProjectOffServerCommand('demo', run: () {}).available, isTrue);
  });

  // Harm: holding another server's record must never enable removal on the project's host.
  for (final held in [false, true]) {
    testWidgets('the project menu selects its associated host record (held: $held)', (tester) async {
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
      } else {
        expect(find.text('Unavailable: the host admin takes a project off its server'), findsOneWidget);
      }
    });
  }

  // Harm: losing a helper refusal or treating it as success can hide unpushed work.
  for (final code in [65, 73, 69, 64, 0]) {
    testWidgets('project removal keeps the helper verdict for exit $code', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      roles = Roles.fromArguments(['--roles', 'host-admin']);
      final scratch = Directory.systemTemp.createTempSync('project-take-off-');
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
                        final script = arguments.last;
                        final project = RegExp(r'porelo-host-project remove ([a-z0-9_-]+)')
                            .firstMatch(script)!
                            .group(1)!;
                        final reply = RegExp(r'> (\S+)/answer 2>').firstMatch(script)!.group(1)!;
                        File('$reply/answer').writeAsStringSync(
                          code == 0
                              ? '${jsonEncode({
                                  'project': project,
                                  'removed': true,
                                  'locked': ['project-worker'],
                                })}\n'
                              : '',
                        );
                        File('$reply/refusal').writeAsStringSync(refusal);
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
      terminal!.endsWith(code);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      await tester.runAsync(() => running);
      await World.settle(tester);
      final action = tester.widget<Wizard>(find.byType(Wizard)).actionSteps.single;
      expect(action.state(), code != 0 ? WizardActionState.refused : WizardActionState.done);
      if (code != 0) {
        expect(tester.widget<SelectableText>(find.byKey(const Key('host-admin-refusal'))).data, refusal);
      } else {
        expect(find.byKey(const Key('host-admin-answer')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
