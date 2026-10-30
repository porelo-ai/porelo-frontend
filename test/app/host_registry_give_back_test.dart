import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_registry.dart';

void main() {
  // Harm: failed give-back deletes a still-rented host, or publication failure causes a second give-back.
  for (final outcome in [
    'refused',
    'unconfirmed',
    'confirmed',
    'confirmed with owner',
    'confirmed revoked',
    'confirmed contact refusal',
  ]) {
    testWidgets('standalone $outcome give-back retains registry recovery', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemorySettingsStore();
      final settings = Settings(store);
      final fixture = RegistryFixture();
      final access = await fixture.access(settings);
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final owner = outcome != 'confirmed' && outcome.startsWith('confirmed')
          ? HostRuns(machines, hostAccess: access)
          : null;
      final confirmed = outcome.startsWith('confirmed');
      final record = HostUpRecord.fromStored({
        'oneClick': true,
        'host': 'orchard',
        'hostName': 'orchard',
        'scalewayProject': 'provider',
        'publicKey': hostKey,
        'preparedHost': sshCompletion(),
      })!;
      await settings.rememberHostUp('orchard', record);
      fixture.fail = 'publish';
      if (outcome == 'confirmed contact refusal') {
        fixture.publicationRefusal = const RegistryRefusal(
          'Signing was refused.',
          whoMay: [RegistryContact(login: 'carol', name: 'Carol', email: 'carol@example.org')],
        );
      }
      if (outcome == 'confirmed revoked') fixture.actor = const HostAdminIdentity('bob', personFingerprint);
      var downs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'orchard',
              machines: machines,
              settings: settings,
              hostAccess: access,
              hostRuns: owner,
              takeDownOnly: true,
              start: (_, arguments) async {
                if (arguments.first == 'down') downs++;
                final process = HostProcess();
                if (outcome != 'unconfirmed') {
                  process.line(
                    host.Step(
                      'give-back',
                      outcome == 'refused' ? host.StepState.refused : host.StepState.done,
                      address: '203.0.113.7',
                    ),
                  );
                }
                process.end(outcome == 'refused' ? 65 : 0);
                return process;
              },
            ),
          ),
        ),
      );
      expect(fixture.changes, isEmpty, reason: 'the confirmation has not been accepted');
      await tester.tap(find.byKey(const Key('host-confirm-down')));
      await World.settle(tester);
      expect(downs, 1);
      expect(
        fixture.changes.map((change) => change.action),
        confirmed && outcome != 'confirmed revoked' ? ['delete-card'] : isEmpty,
      );
      expect(settings.hostRegistry('orchard')?.change.action, confirmed ? 'delete-card' : isNull);
      if (confirmed) {
        expect(find.textContaining('registry card still needs deletion'), findsOneWidget);
        if (outcome == 'confirmed contact refusal') {
          expect(find.textContaining('Signing was refused.'), findsOneWidget);
          expect(find.textContaining('carol@example.org'), findsOneWidget);
        }
        if (outcome == 'confirmed revoked') {
          expect(find.textContaining('alice@example.org'), findsOneWidget);
        }
        final reopened = Settings(store);
        await reopened.load();
        expect(reopened.hostRegistry('orchard')!.published, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        final restored = HostAccess(
          registry: fixture.registry,
          settings: reopened,
          identity: () => fixture.actor,
          writer: WriterFixture(fixture),
          transport: fixture,
        );
        final restoredMachines = Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
        final restoredOwner = owner == null ? null : HostRuns(restoredMachines, hostAccess: restored);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HostDialog(
                project: 'orchard',
                machines: restoredMachines,
                settings: reopened,
                hostAccess: restored,
                hostRuns: restoredOwner,
                takeDownOnly: true,
                start: (_, _) async {
                  downs++;
                  return HostProcess()..end(0);
                },
              ),
            ),
          ),
        );
        await World.settle(tester);
        expect(
          find.textContaining('registry card still needs deletion'),
          findsOneWidget,
          reason: 'pending publication remains visible after a true restart',
        );
        if (outcome == 'confirmed revoked') expect(find.textContaining('alice@example.org'), findsOneWidget);
        fixture.actor = const HostAdminIdentity('alice', adminFingerprint);
        fixture.fail = null;
        fixture.publicationRefusal = null;
        await restored.bringToHost('orchard');
        expect(fixture.changes, hasLength(1), reason: 'deletion publication reuses its commit');
        expect(downs, 1, reason: 'publication does not call down');
        await tester.pumpWidget(const SizedBox.shrink());
        restoredOwner?.dispose();
        restoredMachines.dispose();
        reopened.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      owner?.dispose();
      machines.dispose();
      fixture.registry.dispose();
      settings.dispose();
    });
  }
}
