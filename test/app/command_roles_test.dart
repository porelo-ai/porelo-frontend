import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/agent_sign_in.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/notifications.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/app/vault.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a row's command made up where it is used, its home and wording kept nowhere a test reads.
  test('a row\'s details are a command of the catalogue, at home in the row\'s menu', () {
    final details = seeItsDetailsCommand(run: () {});
    expect(details.id, 'work.details');
    expect(details.home, Home.tileMenu);
    expect(details.label, 'See its details');
  });

  // Harm: a new or duplicated command silently exposes server changes to ordinary work.
  test('each command id has one role and only the declared commands require administration', () async {
    final settings = Settings(MemorySettingsStore());
    final fleet = FleetModel(FakeBackend(World.work));
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines);
    final notifications = Notifications(RecordingNotifier(), settings);
    final operations = Operations();
    final shell = ShellModel();
    final templates = Templates(settings);
    final vault = Vault(keys: MemoryDeviceKeyStore());
    const machine = Machine(name: 'demo server', socketPath: '/tmp/demo.sock', kind: 'host', hostProject: 'demo');
    final run = HostPreparation(
      project: 'demo',
      session: HostSession(executable: 'unused', arguments: const []),
      record: const HostUpRecord(scalewayProject: 'provider', hostName: 'demo', publicKey: '/keys/person.pub'),
    );
    addTearDown(() {
      fleet.dispose();
      runs.dispose();
      machines.dispose();
      notifications.dispose();
      operations.dispose();
      shell.dispose();
      templates.dispose();
      settings.dispose();
    });
    await fleet.connect();
    fleet.selectProject('checkout');
    await templates.keep(
      const Template(name: 'nightly', project: 'checkout', agent: 'agent', mode: Mode.unattended, prompt: 'Build'),
    );
    await settings.rememberHostUp(
      'prepared',
      HostUpRecord.fromStored({...run.record.stored, 'host': 'prepared', 'hostName': 'prepared'})!,
    );
    final commands = <Command>[
      ...commandsFor(
        fleet: fleet,
        machine: machine,
        canForget: true,
        shell: shell,
        settings: settings,
        operations: operations,
        notifications: notifications,
        templates: templates,
        openFinder: () {},
        checkWorkCanStart: () {},
        askToRemove: (_) {},
        askWhichLog: (_) {},
        openSession: (_) {},
        openDetail: () {},
        continueTheWork: (_) {},
        recreate: (_) {},
        nameTheWork: (_) {},
        widenTheWork: (_) {},
        enforceOnTheWork: (_) {},
        narrowTheWork: (_) {},
        openTheGate: () {},
        openEgress: () {},
        removeWhatWasBuilt: () {},
        whyNoRemoval: null,
        checkTheMachine: () {},
        showTheProviders: () {},
        prepareTheProject: () {},
        showTheBackups: () {},
        syncTheUpstream: () {},
        startWork: () {},
        showAgents: () {},
        showTheVault: () {},
        startFromTemplate: (_) {},
        stopEverything: () {},
        stopEverywhere: () {},
        watchAnotherMachine: () {},
        startTheDaemon: () {},
        stopTheDaemon: () {},
        forget: () {},
        showAbout: () {},
        refreshAll: () {},
        anyAnswering: false,
        vault: vault,
        actOnTheVault: (_) {},
        askTheWorkUser: () {},
        addAUser: () {},
      ),
      ...hostMachineCommands(machine: machine, settings: settings, hostRuns: runs, takeDown: () {}),
      prepareServerCommand(open: () {}),
      hostPreparationCommand(project: 'demo', open: () {}),
      hostProtocolCommand(project: 'demo', open: () {}),
      copyHostProtocolCommand(project: 'demo', copy: () {}),
      continueHostPreparationCommand(project: 'demo', goOn: () {}),
      runHostSetupAgainCommand(project: 'demo', hostRuns: runs),
      ...hostRecoveryCommands(run: run, goOn: () {}, takeDown: () {}),
      resumeHostPreparationCommand(run: run, resume: () {}),
      setScalewayKeyCommand(run: () {}),
      projectWorkCommand(open: () {}),
      leaveWorkCommand(() {}),
      restartRunCommand(task: null, open: () {}),
      signInCommand(SigningIn()),
      importTheSignInCommand(SigningIn()),
      signInAnywayCommand(SigningIn()),
      unlockWaitingMessages(machine, fleet, () {}),
      removeWaitingProject(machine, fleet, Project.from(const {'name': 'demo'}), () {}, whyNoRemoval: null),
      askForHeldMessages(machine, fleet),
      retrySilentMachine(machine, fleet),
      repositoryStartCommand(repository: 'repo', onStart: (_) {}),
      removeMessageMemberCommand('person', supported: true, busy: false, run: () {}),
      joinMessagesCommand(person: 'person', busy: false, run: () {}),
      newMessagePasswordCommand(busy: false, run: () {}),
      openElementCommand(),
      listOpenCommand(label: 'Open', home: Home.machineRow, open: () {}),
      listDisclosureCommand(expanded: false, toggle: () {}),
      ...forgeRowCommands(name: 'forge', change: () {}, remove: () {}, busy: false),
      retryAttentionForwardCommand(run: () {}),
      readAttentionMessageCommand(message: HeldMessage.from(const {}), run: () {}),
      grantAttentionCommand(run: () {}),
      openAttentionOperationCommand(run: () {}),
      reviewAttentionWorkCommand(run: () {}),
      missedQuestionsSeenCommand(run: () {}),
      machineNoticeSeenCommand(run: () {}),
      closeListDetailsCommand(() {}),
      for (final allow in [true, false]) questionDecisionCommand(allow: allow, run: () {}),
      putAwayQuestionCommand(run: () {}),
      ...workCommands(
        task: const Task(
          name: 'locked',
          project: 'checkout',
          securityClass: 'team',
          state: '',
          running: false,
          helpers: 0,
          startAction: StartAction.needsVault,
        ),
        fleet: fleet,
        machine: machine,
        askToRemove: (_) {},
        askWhichLog: (_) {},
        openSession: (_) {},
        continueTheWork: (_) {},
        recreate: (_) {},
        nameTheWork: (_) {},
        widenTheWork: (_) {},
        enforceOnTheWork: (_) {},
        narrowTheWork: (_) {},
      ),
    ];
    run.interrupted = true;
    commands.addAll(hostRecoveryCommands(run: run, goOn: () {}, takeDown: () {}));
    for (final command in commands) {
      expect(command.unless('wait').hidden, command.hidden, reason: '${command.id} stays hidden when it waits');
      expect(command.after(() {}).hidden, command.hidden, reason: '${command.id} stays hidden with more to do');
    }
    expect(commands.map((command) => command.id).toSet(), <String>{
      'about.show',
      'agents.show',
      'appearance.dark',
      'appearance.light',
      'appearance.system',
      'attention.retention',
      'authorization.grant',
      'change',
      'detail.close',
      'detail.open',
      'egress.open',
      'everywhere.panic',
      'finder.open',
      'fleet.reconnect',
      'fleet.refresh',
      'forges.show',
      'gate.open',
      'host.again',
      'host.copyProtocol',
      'host.goOn',
      'host.preparation',
      'host.protocol',
      'host.retry',
      'host.setScalewayKey',
      'host.takeDown',
      'host.prepare',
      'join-it',
      'join-reset',
      'list.closeDetails',
      'list.disclose',
      'list.open',
      'machine.addUser',
      'machine.clear',
      'machine.connections',
      'machine.destinations',
      'machine.doctor',
      'machine.forget',
      'machine.noticeSeen',
      'machine.panic',
      'machine.providers',
      'machine.retry/demo server',
      'machine.start',
      'machine.stop',
      'machine.takeDown',
      'machines.add',
      'member-remove person',
      'message.read',
      'messages.ask/demo server',
      'messages.retryForward',
      'messages.removeProject/demo server/demo',
      'messages.unlock/demo server',
      'notifications.mute',
      'open-element',
      'operation.open',
      'operations.file',
      'operations.latest',
      'operations.show',
      'project.backups',
      'project.clear',
      'project.default',
      'project.delete',
      'project.forge',
      'project.itsWork',
      'project.messages',
      'project.prepare',
      'project.startAgents',
      'project.sync',
      'question.allow',
      'question.block',
      'question.putAway',
      'questions.seen',
      'refresh.every/0',
      'refresh.every/30',
      'refresh.every/60',
      'refresh.every/300',
      'refresh.all',
      'remove',
      'setup.workUser',
      'start-in-repo',
      'template.start/checkout/nightly',
      'vault.enroll',
      'vault.make',
      'vault.open',
      'vault.passphrase',
      'vault.show',
      'vault.shut',
      'work.certifyAgain',
      'work.check',
      'work.continue',
      'work.enforcement',
      'work.handIn',
      'work.importTheSignIn',
      'work.label',
      'work.leave',
      'work.log',
      'work.narrow',
      'work.recreate',
      'work.refresh',
      'work.remove',
      'work.rename',
      'work.restartRun',
      'work.resume',
      'work.review',
      'work.session',
      'work.signIn',
      'work.signInAnyway',
      'work.start',
      'work.stop',
      'work.takeBack',
      'work.talk',
      'work.tell',
      'work.unlock',
      'work.widen',
    });
  });
}
