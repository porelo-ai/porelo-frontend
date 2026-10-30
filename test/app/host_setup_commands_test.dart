import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/notifications.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/host_admin.dart';

const _record = HostUpRecord(scalewayProject: 'provider', hostName: 'demo', publicKey: '/keys/person.pub');
const _done = Step(
  'up',
  StepState.done,
  address: '203.0.113.7',
  account: 'worker',
  socket: '/run/user/1007/porelo/porelod.sock',
);

void main() {
  for (final state in ['running', 'waiting', 'interrupted']) {
    // Harm: teardown, forgetting or a second setup can disrupt a server while its setup is unfinished.
    test('conflicting commands wait for a ready server setup that is $state', () async {
      final settings = Settings(MemorySettingsStore());
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final runs = HostRuns(machines);
      final notifications = Notifications(RecordingNotifier(), settings);
      final originalDesk = desk;
      desk = Desk.of('linux', const {});
      addTearDown(() {
        desk = originalDesk;
        notifications.dispose();
        runs.dispose();
        machines.dispose();
        settings.dispose();
      });
      final first = HostProcess();
      final process = HostProcess();
      final resumed = HostProcess();
      var starts = 0;
      final run = runs.start(
        project: 'demo',
        record: _record,
        session: HostSession(
          executable: 'fake',
          arguments: const [],
          start: (_, _) async => switch (starts++) {
            0 => first,
            1 => process,
            _ => resumed,
          },
        ),
      );
      first
        ..line(_done)
        ..line(Step('host', StepState.host, host: PreparedHost.read({...hostValues(), 'name': 'demo'})))
        ..end(0);
      await run.finished;
      final machine = machines.all.singleWhere((machine) => machine.hostProject == 'demo');
      final fleet = machines.of(machine);
      await fleet.untilAsked();
      Command projectServer(String name) => projectCommands(
        project: ProjectOnScreen(
          project: Project(
            name: name,
            securityClass: 'team',
            file: '/project.yml',
            mirror: '',
            pending: 0,
            tasks: 0,
            running: 0,
          ),
          tasks: const [],
        ),
        fleet: fleet,
        hostRuns: runs,
        notifications: notifications,
        openTheGate: () {},
        openEgress: () {},
        prepareTheProject: () {},
        syncTheUpstream: () {},
        showTheBackups: () {},
        checkWorkCanStart: () {},
        removeWhatWasBuilt: () {},
        putOnAServer: () {},
      ).singleWhere((command) => command.id == 'project.server');
      List<Command> conflicting() => [
        hostMachineCommands(
          machine: machine,
          settings: settings,
          hostRuns: runs,
          takeDown: () {},
        ).singleWhere((command) => command.id == 'machine.takeDown'),
        forgetMachineCommand(canForget: true, forget: () {}, machine: machine, hostRuns: runs),
        projectServer('demo'),
        runHostSetupAgainCommand(project: 'demo', hostRuns: runs),
      ];
      expect(conflicting().map((command) => command.id), [
        'machine.takeDown',
        'machine.forget',
        'project.server',
        'host.again',
      ]);
      expect(conflicting().every((command) => command.available), isTrue);
      final again = runs.again('demo');
      if (state != 'running') {
        if (state == 'waiting') process.line(const Step('person', StepState.waiting, needs: ['drive']));
        process.end(state == 'waiting' ? 75 : 65);
        await again;
        if (state == 'interrupted') run.interrupted = true;
      }
      for (final command in conflicting()) {
        expect(command.unavailable, 'its setup is running again; see its protocol', reason: command.id);
      }
      expect(projectServer('another').available, isTrue, reason: 'another project has no competing setup');
      expect(
        forgetMachineCommand(canForget: true, forget: () {}, machine: Machine.local(), hostRuns: runs).available,
        isTrue,
        reason: 'another machine must stay independent of this server',
      );
      final finishing = state == 'running' ? again : runs.resume(run);
      (state == 'running' ? process : resumed)
        ..line(_done)
        ..line(Step('host', StepState.host, host: PreparedHost.read({...hostValues(), 'name': 'demo'})))
        ..end(0);
      await finishing;
      for (final command in conflicting()) {
        expect(command.available, isTrue, reason: '${command.id} must return after successful setup');
      }
    });
  }
}
