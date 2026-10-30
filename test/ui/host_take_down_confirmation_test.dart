import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_registry.dart';

void main() {
  // Harm: failed give-back deletes a still-rented host, or publication failure causes a second give-back.
  for (final outcome in ['refused', 'unconfirmed', 'confirmed']) {
    testWidgets('standalone $outcome give-back retains registry recovery', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemorySettingsStore();
      final settings = Settings(store);
      final fixture = RegistryFixture();
      final access = await fixture.access(settings);
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final record = HostUpRecord.fromStored({
        'host': 'orchard',
        'hostName': 'orchard',
        'scalewayProject': 'provider',
        'account': 'root',
        'tresor': '',
        'folder': null,
        'signingKey': '',
        'identity': '/keys/private',
        'publicKey': '/keys/public',
        'collection': '',
        'vpnPeerPublicKey': '',
        'vpnPeerAddress': '',
      })!;
      await settings.rememberHostUp('orchard', record);
      fixture.fail = 'publish';
      var downs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'orchard',
              machines: machines,
              settings: settings,
              hostAccess: access,
              takeDownOnly: true,
              linux: false,
              debug: false,
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
      await tester.tap(find.byKey(const Key('host-down')));
      await World.settle(tester);
      expect(downs, 1);
      expect(fixture.changes.map((change) => change.action), outcome == 'confirmed' ? ['delete-card'] : isEmpty);
      expect(settings.hostRegistry('orchard')?.change.action, outcome == 'confirmed' ? 'delete-card' : isNull);
      if (outcome == 'confirmed') {
        final reopened = Settings(store);
        await reopened.load();
        expect(reopened.hostRegistry('orchard')!.published, isFalse);
        fixture.fail = null;
        await access.bringToHost('orchard');
        expect(fixture.changes, hasLength(1), reason: 'deletion publication reuses its commit');
        expect(downs, 1, reason: 'publication does not call down');
        reopened.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      machines.dispose();
      fixture.registry.dispose();
      settings.dispose();
    });
  }

  // Harm: one wizard click deletes a rented server without confirming the loss of its data.
  testWidgets('wizard teardown waits for confirmation and Cancel starts nothing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines);
    final commands = <List<String>>[];
    await settings.rememberHostUp(
      'demo',
      const HostUpRecord(
        scalewayProject: 'provider',
        account: 'worker',
        tresor: 'drive',
        folder: null,
        repository: '',
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'demo',
              machines: machines,
              settings: settings,
              hostRuns: runs,
              debug: false,
              start: (_, arguments) async {
                commands.add(List.of(arguments));
                return HostProcess()
                  ..line(const host.Step('give-back', host.StepState.refused, text: 'The provider is unavailable.'))
                  ..end(65);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('host-down')));
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'opening confirmation must not start down');

      await tester.tap(find.text('Cancel'));
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'Cancel must leave the rented server alone');

      await tester.tap(find.byKey(const Key('host-down')));
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'reopening confirmation must still wait');
      await tester.tap(find.text('Give the server back'));
      await World.settle(tester);
      expect(commands.map((arguments) => arguments.first), ['down'], reason: 'confirmation starts exactly one down');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      runs.dispose();
      machines.dispose();
      settings.dispose();
    }
  });
}
