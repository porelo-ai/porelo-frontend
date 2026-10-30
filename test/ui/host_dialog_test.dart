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
  // Harm: preparation must use the chosen pinned host, collection and limits, and retain readiness when signing is unavailable.
  testWidgets('Prepare the host passes public choices and retains the ready host before publication', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = RegistryFixture()..fail = 'file';
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
      fixture.registry.dispose();
    });
    final process = HostProcess();
    List<String>? arguments;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: '',
          machines: machines,
          settings: settings,
          hostRuns: runs,
          pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
          start: (_, args) async {
            arguments = args;
            return process;
          },
        ),
      ),
    );
    Future<void> type(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await World.settle(tester);
      await tester.enterText(field, value);
    }

    await type('Host name', 'orchard');
    await type('Server address', '203.0.113.7');
    await type('SSH host key', hostKey);
    await tester.ensureVisible(find.text('Choose collection'));
    await World.settle(tester);
    await tester.tap(find.text('Choose collection'));
    await tester.pump();
    await type('Collection SHA-256', 'a' * 64);
    await tester.ensureVisible(find.text('More settings'));
    await World.settle(tester);
    await tester.tap(find.text('More settings'));
    await World.settle(tester);
    for (final entry in {'forge_runner_capacity': '1', 'forge_job_cpus': '1', 'forge_job_memory': '768m'}.entries) {
      await tester.ensureVisible(find.byKey(Key(entry.key)));
      await World.settle(tester);
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.ensureVisible(find.text('Use settings'));
    await World.settle(tester);
    await tester.tap(find.text('Use settings'));
    await tester.tap(find.text('Prepare the host'));
    await World.settle(tester);
    final run = runs.of('orchard')!;
    expect(arguments, ['up', ...hostArguments(run.record, 'orchard')]);
    expect(arguments, containsAllInOrder(['--given', '203.0.113.7', '--host-key', hostKey]));
    expect(
      arguments,
      containsAllInOrder(['--forge-runner-capacity', '1', '--forge-job-cpus', '1', '--forge-job-memory', '768m']),
    );
    expect(
      arguments,
      containsAllInOrder(['--collection', '/collections/host.tar.gz', '--collection-sha256', 'a' * 64]),
    );
    process.line(const host.Step('up', host.StepState.done, address: '203.0.113.7', admin: 'root'));
    process.line(host.Step('host', host.StepState.host, host: host.PreparedHost.read(sshCompletion())));
    process.end(0);
    await run.finished;
    await World.settle(tester);
    expect(run.ready, isTrue);
    expect(settings.hostUp('orchard')!.preparedHost!.address, '203.0.113.7');
    expect(find.textContaining('The host is ready.'), findsWidgets);
    final restored = hostUpRestored(settings.hostUp('orchard')!);
    expect(restored.givenAddress, '203.0.113.7');
    expect(restored.givenHostKey, hostKey);
    expect(hostArguments(restored, 'orchard'), contains('/collections/host.tar.gz'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a reused name must not erase rental recovery or crash an active setup dialog.
  for (final collision in ['saved', 'active', 'waiting']) {
    testWidgets('preparation preserves the $collision host with the same name', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
      final fixture = RegistryFixture();
      final runs = HostRuns(machines, hostAccess: await fixture.access(settings));
      addTearDown(() {
        runs.dispose();
        machines.dispose();
        settings.dispose();
        fixture.registry.dispose();
      });
      final process = HostProcess();
      HostPreparation? previous;
      if (collision == 'saved') {
        await settings.rememberHostUp('orchard', signedSetup);
      } else {
        previous = runs.start(
          project: 'orchard',
          record: signedSetup,
          session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
        );
        await tester.pump();
        if (collision == 'waiting') {
          process.line(const host.Step('person', host.StepState.waiting, needs: ['matrix']));
          process.end(75);
          await previous.finished;
        }
      }
      final kept = settings.hostUp('orchard')?.stored;
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            project: '',
            machines: machines,
            hostRuns: runs,
            pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
            start: (_, _) async {
              starts++;
              return HostProcess()..end(65);
            },
          ),
        ),
      );
      for (final field in {
        'Host name': 'orchard',
        'Server address': '203.0.113.7',
        'SSH host key': hostKey,
        'Collection SHA-256': 'a' * 64,
      }.entries) {
        final finder = find.widgetWithText(TextField, field.key);
        await tester.ensureVisible(finder);
        await World.settle(tester);
        await tester.enterText(finder, field.value);
      }
      await tester.ensureVisible(find.text('Choose collection'));
      await World.settle(tester);
      await tester.tap(find.text('Choose collection'));
      await World.settle(tester);
      await tester.tap(find.text('Prepare the host'));
      await World.settle(tester);
      expect(tester.takeException(), isNull);
      expect(starts, 0);
      expect(settings.hostUp('orchard')?.stored, kept);
      if (previous != null) expect(runs.of('orchard'), same(previous));
      expect(find.textContaining('already'), findsWidgets);
      if (collision == 'active') {
        process.end(65);
        await previous!.finished;
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: a retained callback after revocation must never start root preparation.
  testWidgets('Prepare the host rechecks admin permission before starting SSH', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    final fixture = RegistryFixture();
    final access = await fixture.access(settings);
    final runs = HostRuns(machines, hostAccess: access);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
      fixture.registry.dispose();
    });
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: '',
          machines: machines,
          hostRuns: runs,
          pickFile: ({initialDirectory, title}) async => '/collections/host.tar.gz',
          start: (_, _) async {
            starts++;
            return HostProcess();
          },
        ),
      ),
    );
    for (final field in {
      'Host name': 'orchard',
      'Server address': '203.0.113.7',
      'SSH host key': hostKey,
      'Collection SHA-256': 'a' * 64,
    }.entries) {
      final finder = find.widgetWithText(TextField, field.key);
      await tester.ensureVisible(finder);
      await World.settle(tester);
      await tester.enterText(finder, field.value);
    }
    await tester.ensureVisible(find.text('Choose collection'));
    await World.settle(tester);
    await tester.tap(find.text('Choose collection'));
    await World.settle(tester);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare the host'));
    fixture.actor = null;
    button.onPressed!();
    await World.settle(tester);
    expect(starts, 0);
    expect(runs.of('orchard'), isNull);
    expect(find.textContaining('Only a host admin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

HostUpRecord hostUpRestored(HostUpRecord record) => HostUpRecord.fromStored(record.stored)!;
