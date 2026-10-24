import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart';
import '../support/host_process.dart';

void main() {
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
