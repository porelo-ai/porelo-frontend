import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

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
    final restored = _RestoredRuns(fleet, (_, arguments) async {
      commands.add(List.of(arguments));
      return resumed;
    });
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
      final runs = _RestoredRuns(machines, (_, arguments) async {
        commands.add(List.of(arguments));
        return process;
      });
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
      beforeExit.dispose();
      process.end(outcome == 'unreachable' ? 69 : 0);
      await World.settle(tester);
      final reopened = Settings(store);
      await reopened.load();
      final afterRestart = HostRuns(Machines(reopened, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels()));
      final confirmed = outcome == 'confirmed' || outcome == 'missing';
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
    final runs = HostRuns(machines, endpointFor: (_) => '/ready.sock');
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
    expect(runs.preparing, isEmpty);
    final reopened = Settings(store);
    await reopened.load();
    expect(reopened.hostUp('demo')!.preparing, isFalse);
    reopened.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Harm: a refused setup cannot correct its inputs if the project action always reopens a read-only run.
  testWidgets('the project server action opens editable kept answers after an ended preparation', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settings.rememberHostUp('checkout', _record.withPreparation(DateTime.utc(2000)));
    await World.restartApp(tester);
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
  _RestoredRuns(super.machines, this.startCommand);
  final StartHostCommand startCommand;

  @override
  HostSession sessionFor(String project, HostUpRecord record) =>
      HostSession(executable: 'fake', arguments: hostArguments(record, project), start: startCommand);
}
