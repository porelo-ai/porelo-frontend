// Linux only: the replacement lock guard runs a Dart child using POSIX file locks and chmod.
@Tags(['linux'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_process.dart';
import '../support/host_organization.dart';
import '../support/host_admin.dart';

class _Tunnels extends Tunnels {
  final requested = <Machine>[];
  @override
  Future<bool> raiseFor(Machine machine) async {
    requested.add(machine);
    return true;
  }
}

class _RestoredRuns extends HostRuns {
  _RestoredRuns(super.machines, {super.environment, super.hostAccess});
  final commands = <List<String>>[];
  @override
  HostSession sessionFor(String project, HostUpRecord record) => HostSession(
    executable: 'fake',
    arguments: record.giveBackArguments(project),
    start: (_, arguments) async {
      commands.add(arguments);
      final process = HostProcess();
      process.end(65);
      return process;
    },
  );
}

Future<({Settings settings, Machines machines, HostRuns runs, _Tunnels tunnels})> _restore() async {
  final settings = Settings(
    MemorySettingsStore({
      'hostUps': {
        'demo': HostUpRecord(
          scalewayProject: 'provider',
          host: 'demo',
          hostName: 'orchard',
          publicKey: '/keys/person.pub',
          preparedHost: host.PreparedHost.read(hostValues()),
        ).stored,
      },
      'machines': [
        const Machine(
          name: 'demo server',
          kind: 'host',
          hostProject: 'demo',
          host: 'worker@203.0.113.7',
          remoteSocket: '/run/user/1007/porelo/porelod.sock',
          socketPath: '/unused',
        ).stored,
      ],
    }),
  );

  await settings.load();
  final tunnels = _Tunnels();
  final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: tunnels);

  await machines.load();
  final fixture = HostFixture();
  final access = await fixture.access(settings);
  final runs = _RestoredRuns(machines, hostAccess: access, environment: {'XDG_STATE_HOME': Directory.systemTemp.path});

  return (settings: settings, machines: machines, runs: runs, tunnels: tunnels);
}

void main() {
  void dispose(({Settings settings, Machines machines, HostRuns runs, _Tunnels tunnels}) state) {
    state.runs.dispose();
    state.machines.dispose();
    state.settings.dispose();
    state.tunnels.dispose();
  }

  // Harm: a machine goes with a project on it and nobody was told what is safe; or an admin on another computer, who kept
  // nothing from setting it up, cannot take Porelo off.
  testWidgets('taken off by the card, the dialog names what stands on it', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: _Tunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    final access = await (HostFixture()..orchardProjects = const ['demo']).access(settings);
    final commands = <List<String>>[];
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: 'orchard',
          machines: machines,
          settings: settings,
          hostAccess: access,
          takeDownOnly: true,
          fromTheCard: const HostUpRecord(
            hostName: 'orchard',
            givenAddress: '203.0.113.7',
            givenHostKey: hostKey,
            publicKey: personKey,
          ),
          start: (_, arguments) async {
            if (arguments.contains('--memberships')) return _emptyMemberships();
            commands.add(arguments);
            return HostProcess()..end(65);
          },
        ),
      ),
    );
    await World.settle(tester);
    final words = tester.widget<Text>(find.byKey(const Key('host-projects-left'))).data!;
    expect(words, allOf(contains('demo'), contains('central forge')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-confirm-down'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('host-give-back-anyway')));
    await World.settle(tester);
    expect(commands.single, containsAllInOrder(['--given', '203.0.113.7', '--host-key', hostKey]));
    expect(commands.single, contains('--give-back-anyway'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a failed signed-state teardown must leave a deliberate route to stop provider billing.
  testWidgets('signed-state give-back offers an explicit loss-confirmed retry', (tester) async {
    final settings = Settings(MemorySettingsStore());
    await settings.rememberHostUp(
      'orchard',
      const HostUpRecord(scalewayProject: 'provider', publicKey: personKey, hostName: 'orchard'),
    );
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: _Tunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    final commands = <List<String>>[];
    final processes = <HostProcess>[];
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: 'orchard',
          machines: machines,
          settings: settings,
          takeDownOnly: true,
          readHostProgress: (_) async => const HostProgress(),
          start: (_, arguments) async {
            if (arguments.contains('--memberships')) return _emptyMemberships();
            commands.add(arguments);
            final process = HostProcess();
            processes.add(process);
            return process;
          },
        ),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('host-confirm-down')));
    await World.settle(tester);
    processes.single.line(const host.Step('give-back', host.StepState.refused));
    processes.single.end(65);
    await World.settle(tester);
    expect(settings.hostUp('orchard'), isNotNull);
    expect(find.byKey(const Key('host-force-down')), findsOneWidget);
    await tester.tap(find.byKey(const Key('host-force-down')));
    await World.settle(tester);
    expect(commands.last, contains('--give-back-anyway'));
    processes.last.line(const host.Step('give-back', host.StepState.done));
    processes.last.end(0);
    await World.settle(tester);
    expect(settings.hostUp('orchard'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: failed or interrupted give-back must not lose the only record of a billed server.
  for (final confirmed in [false, true]) {
    testWidgets('${confirmed ? 'confirmed' : 'refused'} give-back ${confirmed ? 'clears' : 'keeps'} the rental', (
      tester,
    ) async {
      final state = (await tester.runAsync(_restore))!;
      addTearDown(() => dispose(state));
      final before = state.settings.hostUp('demo')!.stored;
      final process = HostProcess();
      final commands = <List<String>>[];
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            project: 'demo',
            machines: state.machines,
            settings: state.settings,
            hostRuns: state.runs,
            takeDownOnly: true,
            readHostProgress: (_) async => const HostProgress(),
            start: (_, arguments) async {
              if (arguments.contains('--memberships')) return _emptyMemberships();
              commands.add(arguments);
              return process;
            },
          ),
        ),
      );
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'opening give-back cannot delete a rental');
      await tester.tap(find.byKey(const Key('host-confirm-down')));
      await World.settle(tester);
      process.line(host.Step('give-back', confirmed ? host.StepState.done : host.StepState.refused));
      process.end(confirmed ? 0 : 65);
      await World.settle(tester);
      // The restored machine queue belongs to runAsync; its mutation then returns to the widget clock.
      await tester.runAsync(() async {});
      await World.settle(tester);
      expect(commands.single, containsAllInOrder(['down', '--host-name', 'orchard']));
      expect(commands.single, isNot(contains('--identity')));
      if (confirmed) {
        expect(state.settings.hostUp('demo'), isNull);
        expect(state.machines.all.where((m) => m.hostProject == 'demo'), isEmpty);
      } else {
        expect(state.settings.hostUp('demo')!.stored, before);
        expect(state.machines.all.where((m) => m.hostProject == 'demo'), hasLength(1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: an unconfirmed command exit must not be interpreted as provider deletion.
  test('exit zero without the provider give-back line retains recovery', () async {
    final state = await _restore();
    addTearDown(() => dispose(state));
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    addTearDown(session.dispose);
    final pending = session.down();
    process.end(0);
    await pending;
    await state.runs.confirmDown('demo', session);
    expect(state.settings.hostUp('demo'), isNotNull);
  });
}

HostProcess _emptyMemberships() => HostProcess()
  ..line(const host.Step('org-status', host.StepState.done, words: '{"persons":[]}'))
  ..end(0);
