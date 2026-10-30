import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend, FakeTerminal, World;

class _Runs extends HostRuns {
  _Runs(super.machines);
  final resumed = <HostPreparation>[];
  @override
  Future<void> resume(HostPreparation run) async {
    resumed.add(run);
  }
}

void main() {
  // Harm: supported provider sign-ins must remain reachable without collecting secrets in a form.
  for (final need in [
    'vault',
    'vault-new',
    'drive',
    'forge-password',
    'root',
    'legacy',
    'server',
    'dash',
    'unverified',
    'settings-legacy',
  ]) {
    for (final result in (need == 'vault' ? [0, 65, -1] : [65])) {
      testWidgets(
        'the $need stop ${const ['forge-password', 'root', 'legacy', 'server', 'dash', 'unverified', 'settings-legacy'].contains(need) ? 'never starts a terminal' : 'opens only its account terminal'} ($result)',
        (tester) async {
          final settings = Settings(MemorySettingsStore());
          final machines = Machines(settings, reach: (_) => FakeBackend(const []));
          final runs = _Runs(machines);
          final session = HostSession(executable: 'fake', arguments: const [])
            ..address = '192.0.2.7'
            ..account = 'worker';
          final run = HostPreparation(
            project: 'demo',
            session: session,
            record: HostUpRecord(scalewayProject: 'provider', legacy: need == 'legacy'),
            act: need == 'root' ? HostAct.root : HostAct.ownAccount,
            providerMachine: Machine(
              name: 'host account',
              kind: 'host',
              hostProject: need == 'unverified' ? '' : 'orchard',
              host: need == 'dash' ? '-option' : 'worker@orchard',
              socketPath: '',
              remoteSocket: need == 'server' ? '' : '/run/user/1007/porelo',
            ),
          );
          final stopSettings = Settings(MemorySettingsStore());
          addTearDown(stopSettings.dispose);
          if (need == 'settings-legacy') {
            await stopSettings.rememberHostUp('orchard', const HostUpRecord(scalewayProject: 'provider', legacy: true));
          }
          final opened = <List<String>>[];
          final terminals = <FakeTerminal>[];
          addTearDown(() {
            runs.dispose();
            machines.dispose();
            settings.dispose();
            session.dispose();
          });
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openHostStopDialog(
                    context,
                    settings: stopSettings,
                    run: run,
                    hostRuns: runs,
                    machines: machines,
                    needs: [
                      const ['root', 'legacy', 'server', 'dash', 'unverified', 'settings-legacy'].contains(need)
                          ? 'vault'
                          : need,
                    ],
                    openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                      opened.add([program, ...arguments]);
                      final terminal = FakeTerminal([program, ...arguments]);
                      terminals.add(terminal);
                      return terminal;
                    },
                  ),
                  child: const Text('Open stop'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open stop'));
          await World.settle(tester);
          if (const [
            'forge-password',
            'root',
            'legacy',
            'server',
            'dash',
            'unverified',
            'settings-legacy',
          ].contains(need)) {
            expect(find.byKey(const Key('host-open-provider-terminal')), findsNothing);
            expect(opened, isEmpty);
          } else {
            if (need == 'drive') {
              await tester.enterText(find.byKey(const Key('host-drive-email')), 'person@example.org');
              await tester.pump();
            }
            expect(find.byKey(const Key('host-open-provider-terminal')), findsOneWidget);
            await tester.tap(find.byKey(const Key('host-open-provider-terminal')));
            await World.settle(tester);
            expect(opened, hasLength(1));
            expect(opened.single, contains('worker@orchard'));
            expect(opened.single.last, contains(need));
            expect(
              tester.widgetList<TextField>(find.byType(TextField)).where((field) => field.obscureText),
              isEmpty,
              reason: 'provider secrets belong only in the terminal',
            );
            if (result == -1) {
              await tester.tap(find.byKey(const Key('unlock-cancel')));
              await World.settle(tester);
              await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
            } else {
              terminals.single.endsWith(result);
              await World.settle(tester);
              await tester.tap(find.byKey(const Key('unlock-done')));
            }
            await World.settle(tester);
            expect(
              runs.resumed,
              result == 0 ? [run] : isEmpty,
              reason: 'only a successful provider terminal may resume setup',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  // Harm: a Windows stop must use the selected native OpenSSH and its agent, rather than a Linux path.
  testWidgets('a provider terminal selects the desktop OpenSSH installation', (tester) async {
    final previous = desk;
    desk = WindowsDesk(const {'APPDATA': r'D:\Config', 'SystemRoot': r'D:\Windows'});
    addTearDown(() => desk = previous);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []));
    final runs = _Runs(machines);
    final session = HostSession(executable: 'fake', arguments: const []);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
      session.dispose();
    });
    final opened = <List<String>>[];
    final run = HostPreparation(
      project: 'demo',
      session: session,
      record: const HostUpRecord(scalewayProject: 'provider'),
      act: HostAct.ownAccount,
      providerMachine: const Machine(
        name: 'account',
        kind: 'host',
        hostProject: 'orchard',
        host: 'worker@orchard',
        socketPath: '',
        remoteSocket: '/run/user/1007/porelo',
      ),
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostStopDialog(
          run: run,
          hostRuns: runs,
          machines: machines,
          needs: const ['vault'],
          openTerminal: (program, arguments, {columns = 80, rows = 24}) {
            opened.add([program, ...arguments]);
            return FakeTerminal([program, ...arguments]);
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('host-open-provider-terminal')));
    await World.settle(tester);
    expect(opened.single.first, r'D:\Windows\System32\OpenSSH\ssh.exe');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
