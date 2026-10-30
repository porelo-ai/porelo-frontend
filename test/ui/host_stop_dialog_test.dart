import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
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
  for (final need in ['vault', 'vault-new', 'drive', 'forge-password', 'root', 'legacy']) {
    for (final result in (need == 'vault' ? [0, 65, -1] : [65])) {
      testWidgets(
        'the $need stop ${const ['forge-password', 'root', 'legacy'].contains(need) ? 'never starts a terminal' : 'opens only its account terminal'} ($result)',
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
            providerMachine: const Machine(
              name: 'host account',
              kind: 'host',
              hostProject: 'orchard',
              host: 'worker@orchard',
              socketPath: '',
            ),
          );
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
              home: HostStopDialog(
                run: run,
                hostRuns: runs,
                machines: machines,
                needs: [
                  const ['root', 'legacy'].contains(need) ? 'vault' : need,
                ],
                openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                  opened.add([program, ...arguments]);
                  final terminal = FakeTerminal([program, ...arguments]);
                  terminals.add(terminal);
                  return terminal;
                },
              ),
            ),
          );
          if (const ['forge-password', 'root', 'legacy'].contains(need)) {
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
}
