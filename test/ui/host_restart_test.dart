import 'package:porelo_frontend/src/app/roles.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_frontend/src/ui/shell.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/expand_list_rows.dart';

const _record = HostUpRecord(
  scalewayProject: 'kept-provider-project',
  account: 'kept-account',
  tresor: 'kept-drive',
  folder: '/kept/folder',
  signingKey: '/kept/sign.pub',
  identity: '/kept/private',
  publicKey: '/kept/public',
  collection: '/kept/collection',
  collectionSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  vpnPeerPublicKey: 'peer-public',
  vpnPeerAddress: '10.73.0.2/32',
);

void main() {
  setUp(() => roles = Roles.fromArguments(const ['--roles', 'host-admin,project-admin']));
  tearDown(() => roles = const Roles());
  late Directory state;
  late Map<String, String> environment;
  setUp(() async {
    state = await Directory.systemTemp.createTemp('host-restart-');
    environment = {'XDG_STATE_HOME': state.path, 'LOCALAPPDATA': state.path};
  });
  tearDown(() => state.delete(recursive: true));
  // Harm: a billing server disappears after restart, or Go on targets a different server.
  testWidgets('a stopped preparation survives new settings and runs and resumes the kept command', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    final settings = Settings(store);
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final first = HostRuns(machines);
    final stopped = HostProcess();
    final original = HostSession(
      executable: 'fake',
      arguments: hostArguments(_record, 'demo'),
      start: (_, _) async => stopped,
    );
    final run = first.start(project: 'demo', session: original, record: _record, settings: settings);
    stopped.line(const Step('person', StepState.waiting, needs: ['drive']));
    stopped.end(75);
    await World.settle(tester);
    await run.finished;
    first.dispose();
    machines.dispose();
    settings.dispose();

    final reopened = Settings(store);
    await reopened.load();
    final fleet = Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final commands = <List<String>>[];
    final resumed = HostProcess();
    final restored = (await tester.runAsync(
      () async => _RestoredRuns(fleet, (_, arguments) async {
        commands.add(List.of(arguments));
        return resumed;
      }, environment: environment),
    ))!;
    await tester.runAsync(() => restored.of('demo')!.checked);
    addTearDown(() {
      restored.dispose();
      fleet.dispose();
      reopened.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MachinesPage(machines: fleet, hostRuns: restored, onAdd: () {}, onDetails: (_) {}, onForget: (_) {}),
        ),
      ),
    );
    expect(
      find.byKey(const Key('host-preparing demo')),
      findsOneWidget,
      reason: 'a rented server must remain reachable after restart',
    );
    expect(commands, isEmpty, reason: 'restoring must not rent or run anything');
    expect(restored.of('demo')!.session.state, HostRunState.idle);
    expect(restored.of('demo')!.interrupted, isTrue, reason: 'restart must preserve the interrupted preparation');
    await tester.tap(find.text('Go on'));
    var returned = false;
    final overlapping = restored.resume(restored.of('demo')!).then((_) => returned = true);
    await World.settle(tester);
    expect(commands, [
      ['up', ...hostArguments(_record, 'demo')],
    ], reason: 'all kept arguments must target the original server');
    expect(returned, isFalse, reason: 'another click must wait until the running command ends');
    expect(restored.of('demo')!.interrupted, isFalse, reason: 'Go on begins a new attempt');
    resumed.line(const Step('person', StepState.waiting, needs: ['drive']));
    resumed.end(75);
    await World.settle(tester);
    await restored.of('demo')!.finished;
    await overlapping;
    expect(restored.preparing, [restored.of('demo')]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final outcome in ['confirmed', 'refused', 'unreachable', 'missing', 'unconfirmed']) {
    // Harm: unconfirmed teardown loses billing recovery; keeping recovery after confirmed absence can rent a server again.
    testWidgets('interrupted teardown keeps recovery until $outcome give-back', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemorySettingsStore({
        'hostUps': {
          'demo': {..._record.stored, 'preparing': true, 'startedAt': DateTime.utc(2000).toIso8601String()},
        },
      });
      final settings = Settings(store);
      await settings.load();
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      const hostMachine = Machine(
        name: 'demo server',
        kind: 'host',
        socketPath: '/kept/server.sock',
        host: 'kept-account@203.0.113.7',
        remoteSocket: '/run/user/1007/porelo/porelod.sock',
        identity: '/kept/private',
        hostProject: 'demo',
      );
      await machines.add(hostMachine);
      final commands = <List<String>>[];
      final process = HostProcess();
      var vpnChecks = 0;
      final runs = (await tester.runAsync(
        () async => _RestoredRuns(
          machines,
          (_, arguments) async {
            commands.add(List.of(arguments));
            return process;
          },
          environment: environment,
          // VPN checks must not depend on this computer's tunnel or process timing.
          probeLink: () async {
            vpnChecks++;
            return false;
          },
          ping: () async => false,
        ),
      ))!;
      await tester.runAsync(() => runs.of('demo')!.checked);
      addTearDown(() {
        runs.dispose();
        machines.dispose();
        settings.dispose();
      });
      final preparation = runs.of('demo');
      expect(preparation, isNotNull, reason: 'a kept preparation needs its recovery actions');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: runs,
              builder: (_, _) =>
                  MachinesPage(machines: machines, hostRuns: runs, onAdd: () {}, onDetails: (_) {}, onForget: (_) {}),
            ),
          ),
        ),
      );
      await expandListRows(tester, within: find.byKey(const Key('host-preparing demo')));
      await tester.tap(find.text('Take it down'));
      await World.settle(tester);
      expect(commands, isEmpty);
      await tester.tap(find.text('Cancel'));
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'Cancel must never give a server back');
      await tester.tap(find.text('Take it down'));
      await World.settle(tester);
      await tester.tap(find.text('Give the server back'));
      await World.settle(tester);
      expect(commands, [
        ['down', ...hostArguments(_record, 'demo')],
      ]);
      process.line(
        Step(
          'give-back',
          outcome == 'refused'
              ? StepState.refused
              : outcome == 'unconfirmed'
              ? StepState.started
              : StepState.done,
          address: outcome == 'missing' ? null : '203.0.113.7',
          words: outcome == 'missing' ? 'no host carries the project tag' : null,
        ),
      );
      await World.settle(tester);
      final beforeExit = Settings(store);
      await beforeExit.load();
      expect(
        beforeExit.hostUp('demo')!.stored['preparing'],
        isTrue,
        reason: 'a progress line alone must never erase recovery',
      );
      expect(vpnChecks, 0, reason: 'a progress line alone must never authorize VPN teardown');
      beforeExit.dispose();
      process.end(outcome == 'unreachable' ? 69 : 0);
      await World.settle(tester);
      final reopened = Settings(store);
      await reopened.load();
      final afterRestart = (await tester.runAsync(
        () async => HostRuns(
          Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels()),
          environment: environment,
        ),
      ))!;
      await tester.runAsync(() => Future.wait([for (final run in afterRestart.preparing) run.checked]));
      final confirmed = outcome == 'confirmed' || outcome == 'missing';
      expect(
        vpnChecks,
        confirmed && Platform.isLinux ? greaterThan(0) : 0,
        reason: 'confirmed give-back checks the local VPN only on Linux',
      );
      expect(
        find.byKey(const Key('host-done')),
        confirmed ? findsOneWidget : findsNothing,
        reason: 'give-back completes only after provider confirmation and an absent VPN',
      );
      expect(afterRestart.preparing.map((run) => run.project), confirmed ? isEmpty : ['demo']);
      expect(runs.preparing.map((run) => run.project), confirmed ? isEmpty : ['demo']);
      expect(preparation!.interrupted, !confirmed, reason: 'confirmed give-back ends interruption recovery');
      expect(
        machines.all.contains(hostMachine),
        outcome != 'confirmed',
        reason: 'only a confirmed released address identifies a machine to forget',
      );
      expect(reopened.hostUp('demo')!.arguments('demo'), _record.arguments('demo'));
      afterRestart.machines.dispose();
      afterRestart.dispose();
      reopened.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Harm: teardown erases the ready host's setup protocol and recovery destination when it reuses its session.
  testWidgets('ready teardown preserves the completed setup session and never restores preparation', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    final settings = Settings(store);
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    var vpnChecks = 0;
    final runs = HostRuns(
      machines,
      endpointFor: (_) => '/ready.sock',
      // VPN checks must not depend on this computer's tunnel or process timing.
      probeLink: () async {
        vpnChecks++;
        return false;
      },
      ping: () async => false,
    );
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final up = HostProcess();
    final downs = <List<String>>[];
    Future<HostProcess> down(String _, List<String> arguments) async {
      downs.add(List.of(arguments));
      return HostProcess()
        ..line(const Step('give-back', StepState.done, address: '203.0.113.7'))
        ..end(0);
    }

    final session = HostSession(
      executable: 'fake',
      arguments: hostArguments(_record, 'demo'),
      now: () => DateTime.utc(2000),
      start: (executable, arguments) => arguments.first == 'up' ? Future.value(up) : down(executable, arguments),
    );
    final ready = runs.start(project: 'demo', session: session, record: _record, settings: settings);
    up.line(
      const Step(
        'up',
        StepState.done,
        address: '203.0.113.7',
        account: 'worker',
        socket: '/run/user/1007/porelo/porelod.sock',
      ),
    );
    up.end(0);
    await World.settle(tester);
    await ready.finished;
    final address = session.address;
    final protocol = List.of(session.protocol);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                openHostTakeDownDialog(
                  context,
                  project: 'demo',
                  machines: machines,
                  settings: settings,
                  hostRuns: runs,
                  start: down,
                  linux: true,
                  openTerminal: (_, _, {columns = 80, rows = 24}) =>
                      throw StateError('an absent VPN must never open a terminal'),
                ),
              ),
              child: const Text('Open teardown'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open teardown'));
    await World.settle(tester);
    await tester.tap(find.text('Give the server back'));
    await World.settle(tester);
    expect(downs, [
      ['down', ...hostArguments(_record, 'demo')],
    ]);
    expect(session.address, address, reason: 'teardown must not erase the setup destination');
    expect(session.protocol, protocol, reason: 'the completed setup protocol must stay readable');
    expect(vpnChecks, greaterThan(0), reason: 'a ready host still needs its local VPN checked after give-back');
    expect(find.byKey(const Key('host-done')), findsOneWidget, reason: 'the absent VPN completes give-back');
    expect(runs.preparing, isEmpty);
    final reopened = Settings(store);
    await reopened.load();
    expect(reopened.hostUp('demo')!.preparing, isFalse);
    reopened.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: give-back on other platforms crashes by opening an unsupported local PTY.
  testWidgets('off Linux give-back finishes without opening a terminal', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    await settings.rememberHostUp('demo', _record);
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines);
    addTearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    final process = HostProcess();
    var terminals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            machines: machines,
            settings: settings,
            hostRuns: runs,
            takeDownOnly: true,
            linux: false,
            start: (_, _) async => process,
            openTerminal: (_, _, {columns = 80, rows = 24}) {
              terminals++;
              throw StateError('off Linux give-back must never open a terminal');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Give the server back'));
    await World.settle(tester);
    process.line(const Step('give-back', StepState.done, address: '203.0.113.7'));
    process.end(0);
    await World.settle(tester);
    expect(terminals, 0, reason: 'off Linux the interface never manages the local VPN');
    expect(find.byKey(const Key('host-done')), findsOneWidget, reason: 'provider confirmation completes give-back');
    expect(runs.vpnsToTakeDown, isEmpty, reason: 'off Linux no local VPN cleanup belongs in Needs you');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a refused setup cannot correct its inputs if the project action always reopens a read-only run.
  testWidgets('the project server action opens editable kept answers after an ended preparation', (tester) async {
    final installed = Shell.poreloHostIsHere;
    Shell.poreloHostIsHere = true;
    addTearDown(() => Shell.poreloHostIsHere = installed);
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settings.rememberHostUp('checkout', _record.withPreparation(DateTime.utc(2000)));
    await World.restartApp(tester);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    await _settleChecks(tester, tester.widget<MachinesPage>(find.byType(MachinesPage)).hostRuns!);
    World.machines.fleet.selectProject('checkout');
    World.shell.goTo(Section.project);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('project-menu')));
    await World.settle(tester);
    // The project menu is long; its server entry is scrolled into view before the tap.
    await tester.ensureVisible(find.byKey(const Key('project.server')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('project.server')));
    await World.settle(tester);
    final provider = find.byKey(const Key('host-scaleway-project'));
    expect(provider, findsOneWidget, reason: 'ended setup must allow correcting the provider project');
    expect(tester.widget<TextField>(provider).controller!.text, _record.scalewayProject);
    await tester.enterText(provider, 'corrected-provider');
    expect(tester.widget<TextField>(provider).controller!.text, 'corrected-provider');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: closing without accounting for every unfinished host hides ongoing charges; Cancel must retain recovery.
  testWidgets('the close guard includes every unfinished host and cancel keeps the interface', (tester) async {
    await World.startBackend([]);
    await World.startApp(tester);
    for (final project in ['demo', 'other']) {
      await World.settings.rememberHostUp(
        project,
        HostUpRecord.fromStored({
          ..._record.stored,
          'preparing': true,
          'startedAt': DateTime.utc(2000).toIso8601String(),
        })!,
      );
    }
    await World.restartApp(tester);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    await _settleChecks(tester, tester.widget<MachinesPage>(find.byType(MachinesPage)).hostRuns!);
    // ignore: invalid_use_of_protected_member
    final closing = tester.binding.handleRequestAppExit();
    await World.settle(tester);
    expect(find.byKey(const Key('leaving-host demo')), findsOneWidget);
    expect(find.byKey(const Key('leaving-host other')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quit-cancel')));
    await World.settle(tester);
    expect(await closing, AppExitResponse.cancel);
    expect(find.byKey(const Key('host-preparing demo')), findsOneWidget);
    expect(find.byKey(const Key('host-preparing other')), findsOneWidget);
  });
}

class _RestoredRuns extends HostRuns {
  _RestoredRuns(super.machines, this.startCommand, {super.environment, super.probeLink, super.ping});
  final StartHostCommand startCommand;

  @override
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: 'fake', arguments: hostArguments(record, project), start: startCommand);
}

// File events need fake microtasks pumped between the probe's asynchronous operations.
Future<void> _settleChecks(WidgetTester tester, HostRuns runs) async {
  var checked = false;
  unawaited(Future.wait([for (final run in runs.preparing) run.checked]).then((_) => checked = true));
  for (var turn = 0; turn < 500 && !checked; turn++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await World.settle(tester);
  }
  expect(checked, isTrue, reason: 'restored setup must finish its lock check before testing recovery actions');
}
