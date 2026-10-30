import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_registry.dart';
import '../support/host_rental.dart';
import '../support/signed_host.dart';

void main() {
  // Harm: opening a retained protocol must not start a second command or lose its refusal.
  testWidgets('the retained setup protocol remains visible without starting another command', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    addTearDown(fixture.registry.dispose);
    final runs = HostRuns(machines, hostAccess: access);
    final process = HostProcess();
    var starts = 0;
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      start: (_, _) async {
        starts++;
        return process;
      },
    );
    final run = runs.start(project: 'orchard', record: signedSetup, session: session);
    process.line(const host.Step('up', host.StepState.refused, fix: 'The signed state was refused.'));
    process.end(65);
    await run.finished;
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'orchard', machines: machines, settings: settings, hostRuns: runs, existingRun: run),
      ),
    );
    await World.settle(tester);
    expect(starts, 1);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
