import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guided_walk/guided_walk.dart';

import '../app/desk.dart';
import '../app/homeserver_forwards.dart';
import '../app/host_runs.dart';
import '../app/product.dart';
import '../app/project_access.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/machine_binding.dart';
import '../app/machine_clearing.dart';
import '../app/login_forward.dart';
import '../app/granting.dart';
import '../app/attention.dart';
import '../app/commands.dart';
import '../app/fleet_backend.dart';
import '../app/fleet_model.dart';
import '../app/egress.dart';
import '../app/agent_inventory.dart';
import '../app/authentication.dart';
import '../app/backups.dart';
import '../app/project_check.dart';
import '../app/emergency_stop.dart';
import '../app/start_agents.dart';
import '../app/start_work.dart';
import '../app/templates.dart';
import '../app/tunnel.dart';
import '../app/vault.dart';
import '../app/widening.dart';
import '../app/work_held.dart';
import '../app/gate.dart';
import '../app/host_readiness.dart';
import '../app/logs.dart';
import '../app/notifications.dart';
import '../app/machines.dart';
import '../app/narrowing.dart';
import '../app/newer_version.dart';
import '../app/operations.dart';
import '../app/connections.dart';
import '../app/project_following.dart';
import '../app/vault_unlock.dart';
import '../app/project_deletion.dart';
import '../app/hand_in.dart';
import '../app/session.dart';
import '../app/unattended_run.dart';
import 'clearing_view.dart';
import '../app/settings.dart';
import 'project_join_dialog.dart';
import '../app/shell_model.dart';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostFilesRefused;

import 'attention_view.dart';
import 'command_finder.dart';
import 'clearance_mode_view.dart';
import 'egress_view.dart';
import 'agents_view.dart';
import 'authentication_view.dart';
import 'backups_view.dart';
import 'emergency_stop_view.dart';
import 'connection_wizard.dart';
import 'connections_view.dart';
import 'pick_a_file.dart';
import 'project_following_view.dart';
import 'unlock_terminal.dart';
import 'project_deletion_view.dart';
import 'projects_page.dart';
import 'session_view.dart';
import 'shell_rail.dart';
import 'vault_actions.dart';
import 'vault_view.dart';
import 'start_agents_view.dart';
import 'start_work_view.dart';
import 'widening_view.dart';
import 'gate_view.dart';
import 'words_dialog.dart';
import 'host_readiness_view.dart';
import 'leaving.dart';
import 'log_view.dart';
import 'machine_switcher.dart';
import 'machine_tree.dart';
import 'machine_view.dart';
import 'machines_page.dart';
import 'narrowing_view.dart';
import 'operations.dart';
import 'panes.dart';
import 'destinations_view.dart';
import 'grant_view.dart';
import 'messages_view.dart';
import 'repositories_view.dart';
import 'project_forge_view.dart';
import 'project_developers_dialog.dart';
import 'default_view.dart';
import 'forges_page.dart';
import 'peers_view.dart';
import 'prepare_view.dart';
import 'refusal.dart';
import 'status_line.dart';
import 'tile_console.dart';
import 'tokens.dart';
import 'window_size.dart';
import 'work_page.dart';
import 'wsl_machine.dart';
import 'dialog_scroll.dart';
import 'host_dialog.dart';
import 'host_stop_dialog.dart';

/// The one window: a rail saying where you are, and that place beside it.
///
/// The rail is what needs a person and then every machine. A machine's place holds everything
/// about it: its title and menu, its projects, its work, and a status line of what it ran. The menu
/// bar keeps only what belongs to no machine. Everything else opens over the frame rather than
/// navigating away from it.
class Shell extends StatefulWidget {
  /// Constructor taking everything the frame renders and acts on.
  const Shell({
    required this.machines,
    required this.shell,
    required this.settings,
    required this.operations,
    required this.logs,
    required this.gate,
    required this.notifications,
    required this.egress,
    required this.widening,
    required this.starting,
    required this.inventory,
    required this.templates,
    required this.stopping,
    required this.vault,
    required this.newerVersion,
    required this.sessions,
    required this.deleting,
    required this.readiness,
    required this.authentication,
    required this.following,
    required this.connections,
    this.forges,
    this.projectAccess,
    this.pickAFile = pickWithTheDesktop,
    required this.backups,
    required this.narrowing,
    required this.held,
    this.walk,
    super.key,
  });

  /// The guided walk, in a development build started with one: shown again from the top bar once
  /// it was put away.
  final WalkSession? walk;

  /// The project-scoped Core and host adapters, supplied once their contracts are served.
  final ProjectAccess? Function(String project)? projectAccess;

  /// Every machine being watched, and which one is being acted on.
  final Machines machines;

  /// Where you are, what is open and what the finder is showing.
  final ShellModel shell;

  /// How the interface looks.
  final Settings settings;

  /// What this session has run.
  final Operations operations;

  /// What this session is reading.
  final Logs logs;

  /// What is waiting at the gate of the project being looked at.
  final Gate gate;

  /// What gets told to somebody who is not looking at the window.
  final Notifications notifications;

  /// What the project being looked at may reach.
  final Egress egress;

  /// Letting work that is already running reach something new.
  final Widening widening;

  /// Starting work, and continuing a finished run.
  final StartWork starting;

  /// What agents are installed on the machine being watched.
  final AgentInventory inventory;

  /// The recurring jobs somebody named.
  final Templates templates;

  /// Cutting every form of access at once.
  final EmergencyStop stopping;

  /// What the vault holds.
  final Vault vault;

  /// Whether a newer build has been installed underneath this one.
  final NewerVersion newerVersion;

  /// The shells somebody has open inside running work.
  final Sessions sessions;

  /// Removing what Porelo built for a project.
  final ProjectDeletion deleting;

  /// Whether the machine being acted on can run anything.
  final HostReadiness readiness;

  /// What the machine being acted on can authenticate against.
  final Authentication authentication;

  /// Following a repository, which is how a project comes to a machine.
  final ProjectFollowing following;

  /// How a machine connects out.
  final Connections connections;

  /// A person's forge login and what it reaches, or null for the platform's own, made when first used.
  final ForgeConnection? forges;

  /// Asks the desktop for a file of this computer. Replaced in tests, which have no desktop.
  final PickAFile pickAFile;

  /// What has been backed up of the project being looked at.
  final Backups backups;

  /// Taking a name back from work that is already running.
  final Narrowing narrowing;

  /// What the work being looked at holds that never reached the gate.
  final WorkHeld held;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  /// What is on the machine being acted on. Switching machine changes everything drawn from it.
  FleetModel get _fleet => widget.machines.fleet;

  final _openedFocus = FocusNode(debugLabel: 'opened');
  final _scaffold = GlobalKey<ScaffoldState>();

  /// Starting the agent each repository of a project names, at one click.
  final _startingAgents = StartAgents();
  // The frame's own focus, so the keyboard works the moment the window opens and after anything
  // open over it closes.
  final _frameFocus = FocusNode(debugLabel: 'frame');
  late final Attention _attention;
  late final HostRuns _hostRuns;

  /// A file being handed to work, and the last one's outcome.
  final _handing = HandingIn();

  /// A followed project checked now, at a person's word, rather than at the machine's next round.
  final _check = ProjectCheck();

  /// What the open work's name has been handed, asked when it opens.
  final _handIns = HandInRecord();

  /// The homeservers joined from here, forwarded while the window runs.
  late final HomeserverForwards _homeservers;
  late final AppLifecycleListener _leaving;
  final _runs = <String, UnattendedRun>{};

  /// This build's version, stamped by the package build; a build from source says so.
  static const _version = String.fromEnvironment('PORELO_VERSION', defaultValue: 'built from source');

  @override
  void initState() {
    super.initState();
    _hostRuns = HostRuns(widget.machines);
    _attention = Attention(widget.machines, widget.settings, widget.operations)..hostRuns = _hostRuns;
    _homeservers = HomeserverForwards(widget.settings);
    // One that cannot be raised is said under Needs you; the project's page says the address.
    _attention.homeservers = _homeservers;
    _homeservers.addListener(_homeserversChanged);
    _check.addListener(_homeserversChanged);
    // What was joined before is reachable again from the start, at the same port.
    unawaited(_homeservers.restore(widget.machines));
    // Which forges are set up is read now, asking none of them anything, so a project's menu can say
    // whether its repository's forge is one of them.
    unawaited(_forges.readList());
    // Closing the window is how the interface ends, so the forwards it raised end with it.
    _leaving = AppLifecycleListener(onExitRequested: _letGo);
    widget.shell.addListener(_moveKeyboard);
    widget.sessions.addListener(_moveKeyboard);
    widget.settings.addListener(_keepRefreshing);
    _keepRefreshing();
  }

  Timer? _refreshing;
  int _refreshingEvery = -1;

  /// Asks every machine again on its own, as often as the settings say; never when set to zero.
  void _keepRefreshing() {
    final every = widget.settings.refreshSeconds;
    if (every == _refreshingEvery) return;
    _refreshingEvery = every;
    _refreshing?.cancel();
    _refreshing = every <= 0
        ? null
        : Timer.periodic(Duration(seconds: every), (_) => unawaited(_refreshAll(quietly: true)));
  }

  /// Asks every answering machine again. Only the one open says so, and only when asked by hand.
  Future<void> _refreshAll({bool quietly = false}) async {
    for (final machine in widget.machines.all) {
      final fleet = widget.machines.of(machine);
      if (fleet.reachability != Reachability.connected) continue;
      await fleet.refresh(quietly: quietly || fleet != _fleet);
    }
    if (_fleet.reachability == Reachability.connected) {
      await widget.vault.lookAt(_fleet.backend, widget.machines.current.name);
    }
  }

  /// Stops setup still renting, preserves remote work, and releases this window's forwards.
  Future<AppExitResponse> _letGo() async {
    final running = <String>[
      for (final machine in widget.machines.all)
        for (final task in widget.machines.of(machine).tasks)
          if (task.running) '${task.name} on ${machine.name}',
    ];
    final waiting = widget.machines.all
        .map((machine) => widget.machines.of(machine).clearance.count)
        .fold<int>(0, (all, some) => all + some);
    final agreed = await confirmQuit(
      context,
      running: running,
      waiting: waiting,
      preparing: _hostRuns.preparing.map((run) => run.project).toList(),
      continuingSetup: [
        for (final run in _hostRuns.preparing)
          if (run.running && !run.session.renting) run.project,
      ],
      onLeave: _hostRuns.leave,
    );
    if (!agreed) return AppExitResponse.cancel;
    // Only what this interface raised is taken down; nothing somebody else raised is in there.
    await widget.machines.letGoOfTheTunnels();
    // And the forwards raised for one login, one grant or one homeserver, where one is still open.
    await letGoOfTheForwards();
    return AppExitResponse.exit;
  }

  void _moveKeyboard() {
    if (!mounted) return;
    // A session shown where it belongs holds the keyboard as much as anything opened over the frame.
    final open = widget.shell.anythingOpen || _consoleIsHere;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open) {
        _openedFocus.requestFocus();
      } else if (!_frameFocus.hasFocus) {
        _frameFocus.requestFocus();
      }
    });
  }

  List<Command> _commands() => commandsFor(
    viewActions: _viewActions(),
    fleet: _fleet,
    machine: widget.machines.current,
    hostRuns: _hostRuns,
    hostActions: [
      ..._hostCommands(widget.machines.current),
      for (final run in _hostRuns.preparing)
        ...hostRecoveryCommands(
          run: run,
          goOn: () => unawaited(_hostRuns.resume(run)),
          takeDown: () => unawaited(
            openHostTakeDownDialog(
              context,
              project: run.project,
              machines: widget.machines,
              settings: widget.settings,
              hostRuns: _hostRuns,
            ),
          ),
        ),
    ],
    canForget: widget.machines.all.length > 1,
    shell: widget.shell,
    settings: widget.settings,
    operations: widget.operations,
    notifications: widget.notifications,
    templates: widget.templates,
    openFinder: _openFinder,
    checkWorkCanStart: _checkWorkCanStart,
    askToRemove: _askToRemove,
    askWhichLog: _askWhichLog,
    openSession: _openSession,
    openDetail: _openWork,
    continueTheWork: _continueTheWork,
    recreate: _recreate,
    nameTheWork: _nameTheWork,
    widenTheWork: (_) => _widenTheWork(),
    enforceOnTheWork: (_) => _enforceOnTheWork(),
    narrowTheWork: (_) => _narrowTheWork(),
    talkForTheWork: _talkForTheWork,
    tellTheWork: (task) => unawaited(_tellTheWork(task)),
    handInTo: (task) => unawaited(_handInTo(task)),
    takeBackFrom: (task) => unawaited(_takeBackFrom(task)),
    refreshFromItsSource: (task) => unawaited(_refreshFromItsSource(task)),
    unlockTheVault: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
    openTheGate: _openTheGate,
    openEgress: _openEgress,
    removeWhatWasBuilt: _removeWhatWasBuilt,
    clearTheProject: _clearTheProject,
    registryAccessUnavailable: widget.projectAccess?.call(_fleet.selectedProject?.name ?? '') == null
        ? 'Verified registry project access is not available yet.'
        : null,
    putOnAServer: desk.isWindows ? null : _registerCallback(_fleet.selectedProject),
    openDevelopers: desk.isWindows ? null : _developersCallback(_fleet.selectedProject),
    joinOnItsHost: desk.isWindows ? null : () => unawaited(_joinOnItsHost()),
    takeOffServerBusy: _takeOffServerBusy(_fleet.selectedProject?.name),
    startTheAgents: switch (_fleet.selectedProject?.project.name) {
      final name? => () => unawaited(_startTheAgents(name)),
      null => null,
    },
    checkTheMachine: _checkTheMachine,
    startThenCheck: () => unawaited(_startThenCheck()),
    showTheProviders: _showTheProviders,
    prepareTheProject: _prepareTheProject,
    followARepository: _followARepository,
    fromARepository: _fromARepository,
    showTheForges: _showTheForges,
    showTheBackups: _showTheBackups,
    syncTheUpstream: _syncTheUpstream,
    startWork: _startWork,
    showTheMessages: () => unawaited(_showTheMessages()),
    openItsForge: () => unawaited(_openItsForge()),
    itsForgeIsMissing: _itsForgeIsMissing(),
    showTheDefault: () => unawaited(_showTheDefault()),
    showAgents: _showAgents,
    showTheVault: _showTheVault,
    showConnections: () => unawaited(_showConnections()),
    showDestinations: () => unawaited(showDestinations(context, _fleet.backend)),
    startFromTemplate: _startFromTemplate,
    stopEverything: _stopEverything,
    stopEverywhere: _stopEverywhere,
    watchAnotherMachine: _addAMachine,
    prepareServer: () => unawaited(
      openPrepareServerDialog(context, machines: widget.machines, settings: widget.settings, hostRuns: _hostRuns),
    ),
    startTheDaemon: () => unawaited(_startTheDaemon()),
    stopTheDaemon: () => unawaited(_stopTheDaemon()),
    forget: _forget,
    clearTheMachine: _clearTheMachine,
    showAbout: _showAbout,
    refreshAll: () => unawaited(_refreshAll()),
    anyAnswering: widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected),
    vault: widget.vault,
    actOnTheVault: (act) => unawaited(_actOnTheVault(act)),
    askKeepResolved: () => unawaited(_askKeepResolved()),
    askTheWorkUser: () => unawaited(_askTheWorkUser()),
    addAUser: () => unawaited(_addAUser()),
    unlockWithThePassphrase: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
    makeTheVault: _canMakeHere ? () => unawaited(_makeTheVault()) : null,
  );

  UnattendedRun? get _openedRun => switch (widget.shell.opened) {
    OperationOpened(:final id) => _runs[id],
    _ => null,
  };

  List<Command> _viewActions() {
    final run = _openedRun;
    if (run != null) {
      return [
        leaveWorkCommand(widget.shell.close, unavailable: run.operation.running ? 'the start is still running' : null),
        _restartCommand(run),
      ];
    }
    final session = widget.sessions.current;
    return session == null ? [] : [leaveWorkCommand(() => unawaited(widget.sessions.leave()))];
  }

  Command _restartCommand(UnattendedRun run) => restartRunCommand(
    task: run.task,
    open: () => unawaited(_restartTheRun(run)),
    unavailable: run.operation.running
        ? 'the start is still running'
        : run.operation.failed
        ? 'the start failed'
        : !widget.machines.all.contains(run.machine)
        ? 'the machine is no longer watched'
        : notAnswering(run.fleet) ?? StartWork.whyNot(run.configuration),
  );

  Future<void> _restartTheRun(UnattendedRun run) async {
    final task = run.task;
    final project = run.configuration;
    if (task == null || project == null || !_restartCommand(run).available) return;
    widget.machines.select(run.machine);
    run.fleet.selectProject(project.name);
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.restartFrom(run.fleet.backend, project, task));
    await _offerToStart();
  }

  /// The menu in the machine's title, for the machine being acted on.
  List<Command> _machineMenu() => machineCommands(
    fleet: _fleet,
    machine: widget.machines.current,
    hostRuns: _hostRuns,
    hostActions: _hostCommands(widget.machines.current),
    canForget: widget.machines.all.length > 1,
    reachedOverSsh: widget.machines.current.needsATunnel,
    canStart: widget.machines.current.canBeStartedHere,
    checkTheMachine: _checkTheMachine,
    startThenCheck: () => unawaited(_startThenCheck()),
    showTheProviders: _showTheProviders,
    showTheVault: _showTheVault,
    showConnections: () => unawaited(_showConnections()),
    showDestinations: () => unawaited(showDestinations(context, _fleet.backend)),
    showAgents: _showAgents,
    startTheDaemon: () => unawaited(_startTheDaemon()),
    stopTheDaemon: () => unawaited(_stopTheDaemon()),
    forget: _forget,
    clearTheMachine: _clearTheMachine,
    vault: widget.vault,
    actOnTheVault: (act) => unawaited(_actOnTheVault(act)),
    addAUser: () => unawaited(_addAUser()),
    unlockWithThePassphrase: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
    makeTheVault: _canMakeHere ? () => unawaited(_makeTheVault()) : null,
  );

  List<Command> _hostCommands(Machine machine) {
    final run = _hostRuns.of(machine.hostProject);
    return [
      if (run != null)
        hostProtocolCommand(project: run.project, open: () => unawaited(_openHostRun(run)), home: Home.machineMenu),
      ...hostMachineCommands(
        machine: machine,
        settings: widget.settings,
        hostRuns: _hostRuns,
        takeDown: () => unawaited(_takeDown(machine)),
      ),
    ];
  }

  Future<void> _takeDown(Machine machine) async {
    await openHostTakeDownDialog(
      context,
      project: machine.hostProject,
      machines: widget.machines,
      settings: widget.settings,
      hostRuns: _hostRuns,
      openTerminal: widget.sessions.openTerminal,
    );
    if (mounted && !widget.machines.all.contains(machine)) widget.shell.goTo(Section.machines);
  }

  /// A project card's menu, judged for that project and run with it selected.
  List<Command> _projectMenu(ProjectOnScreen project, {Machine? on}) => <Command>[
    for (final command in projectCommands(
      project: project,
      settings: widget.settings,
      fleet: on == null ? _fleet : widget.machines.of(on),
      hostRuns: _hostRuns,
      notifications: widget.notifications,
      openTheGate: _openTheGate,
      openEgress: _openEgress,
      prepareTheProject: _prepareTheProject,
      syncTheUpstream: _syncTheUpstream,
      showTheBackups: _showTheBackups,
      checkWorkCanStart: _checkWorkCanStart,
      removeWhatWasBuilt: _removeWhatWasBuilt,
      clearTheProject: _clearTheProject,
      registryAccessUnavailable: widget.projectAccess?.call(project.name) == null
          ? 'Verified registry project access is not available yet.'
          : null,
      putOnAServer: desk.isWindows ? null : _registerCallback(project),
      openDevelopers: desk.isWindows ? null : _developersCallback(project),
      joinOnItsHost: desk.isWindows ? null : () => unawaited(_joinOnItsHost()),
      takeOffServerBusy: _takeOffServerBusy(project.name),
      showTheMessages: () => unawaited(_showTheMessages()),
      openItsForge: () => unawaited(_openItsForge()),
      itsForgeIsMissing: _itsForgeIsMissing(),
      showTheDefault: () => unawaited(_showTheDefault()),
      startTheAgents: () => unawaited(_startTheAgents(project.name)),
    ))
      // Run on the project's own machine, with it chosen there: a row on Projects can be another
      // machine's than the one acted on.
      command.after(() {
        if (on != null) widget.machines.select(on);
        _fleet.selectProject(project.name);
      }),
  ];

  /// What concerns a project as a whole, on its row's menu and its page's (walk 9):
  /// starting work, what waits at its gate, being told about it, clearing it, letting it go.
  static const List<String> _projectAsAWhole = <String>[
    'work.start',
    'project.startAgents',
    'gate.open',
    'notifications.mute',
    'project.clear',
    'project.server',
    'project.developers',
    'project.takeOffServer',
    'project.delete',
  ];

  /// The project's menu: what concerns it as a whole.
  List<Command> _projectRowMenu(ProjectOnScreen project, {Machine? on}) => <Command>[
    for (final command in _projectMenu(project, on: on))
      if (_projectAsAWhole.contains(command.id)) command,
  ];

  /// A tile's actions, judged on the tile's own machine and run with its work selected there.
  List<Command> _tileActions(Tile tile) => <Command>[
    for (final command in workCommands(
      task: tile.task,
      fleet: tile.fleet,
      machine: tile.machine,
      askToRemove: _askToRemove,
      askWhichLog: _askWhichLog,
      openSession: _openSession,
      continueTheWork: _continueTheWork,
      recreate: _recreate,
      nameTheWork: _nameTheWork,
      widenTheWork: (_) => _widenTheWork(),
      enforceOnTheWork: (_) => _enforceOnTheWork(),
      narrowTheWork: (_) => _narrowTheWork(),
      talkForTheWork: _talkForTheWork,
      tellTheWork: (task) => unawaited(_tellTheWork(task)),
      handInTo: (task) => unawaited(_handInTo(task)),
      takeBackFrom: (task) => unawaited(_takeBackFrom(task)),
      refreshFromItsSource: (task) => unawaited(_refreshFromItsSource(task)),
      unlockTheVault: _unlockFor(tile.machine),
    ))
      command.after(() => _actOn(tile)),
  ];

  /// Makes a tile's machine and work the ones being acted on, **and changes nothing about where
  /// somebody is**: acting on work from Running leaves Running on screen, and from a project that
  /// project. Reported: a session opened from Running and put away came
  /// back to the work's project, because acting narrowed to it.
  void _actOn(Tile tile) {
    widget.machines.select(tile.machine);
    final task = tile.task;
    if (task != null) tile.fleet.selectTask(task.name);
  }

  /// The project [work] belongs to, as this machine lists it, without selecting it.
  ProjectOnScreen? _projectOf(Task work) =>
      _fleet.projects.where((project) => project.name == work.project).firstOrNull;

  /// Goes to where a tile's work lives: its machine, its project, the work itself.
  void _select(Tile tile) {
    widget.machines.select(tile.machine);
    final task = tile.task;
    if (task == null) return;
    if (tile.fleet.selectedTask?.name == task.name) return;
    tile.fleet
      ..selectProject(task.project)
      ..selectTask(task.name);
  }

  /// Goes from what needs a person to where the tile's work lives.
  void _goToWork(Tile tile) {
    _select(tile);
    widget.shell.goTo(Section.work);
  }

  /// Opens what is waiting at a project's gate: [work]'s own, or the selected project's.
  Future<void> _openTheGate([Task? work]) async {
    final project = (work == null ? _fleet.selectedProject : _projectOf(work))?.project;
    if (project == null) return;
    widget.shell.openGate();
    await widget.gate.lookAt(_fleet.backend, project);
  }

  /// Clears the selected project from the machine, and the machine's keys for it at the forge.
  Future<void> _clearTheProject() async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    await openClearing(
      context,
      MachineClearing(_fleet.backend, _forges, machineName: widget.machines.current.name, project: project.name),
    );
    unawaited(_fleet.refresh(quietly: true));
  }

  Future<void> _openHostRun(HostPreparation run) => run.needsYou
      ? openHostStopDialog(
          context,
          run: run,
          hostRuns: _hostRuns,
          machines: widget.machines,
          settings: widget.settings,
          openTerminal: widget.sessions.openTerminal,
          needs: run.asksOnItsOwn,
        )
      : openHostRunDialog(
          context,
          run: run,
          hostRuns: _hostRuns,
          machines: widget.machines,
          settings: widget.settings,
          openTerminal: widget.sessions.openTerminal,
        );

  VoidCallback? _registerCallback(ProjectOnScreen? project) =>
      project == null ? null : () => unawaited(_putOnAServer(project));

  VoidCallback? _developersCallback(ProjectOnScreen? project) =>
      project == null ? null : () => unawaited(_openDevelopers(project));

  Future<void> _putOnAServer(ProjectOnScreen project) async {
    if (project.name == defaultProject || !project.canBeActedOn || widget.projectAccess?.call(project.name) == null) {
      return;
    }
    await openHostDialog(
      context,
      access: widget.projectAccess?.call(project.name),
      backend: _fleet.backend,
      project: project.name,
      machines: widget.machines,
      settings: widget.settings,
      openTerminal: widget.sessions.openTerminal,
    );
  }

  Future<void> _joinOnItsHost() async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    await openProjectJoinDialog(
      context,
      project: project.name,
      backend: _fleet.backend,
      machines: widget.machines,
      settings: widget.settings,
      openTerminal: widget.sessions.openTerminal,
    );
  }

  /// Why the project's server cannot take a removal now: its own setup is preparing, running, waiting or interrupted.
  String? _takeOffServerBusy(String? project) {
    final host = project == null ? null : widget.settings.projectHost(project);
    final record = host == null ? null : widget.settings.hostUp(host);
    if (record == null) return null;
    final run = _hostRuns.of(record.hostName);
    return record.preparing || run != null && (run.running || run.needsYou || run.interrupted)
        ? 'its server’s setup is under way; see its protocol'
        : null;
  }

  /// Clears the machine and removes its trusted message signer from followed projects.
  Future<void> _clearTheMachine() async {
    await openClearing(context, MachineClearing(_fleet.backend, _forges, machineName: widget.machines.current.name));
    unawaited(_fleet.refresh(quietly: true));
  }

  /// Asks what removing what Porelo built for this project would take, then offers to do it.
  ///
  /// **Nothing is removed by opening this.** The preview is a call with `dryRun`, and what it
  /// lists is what somebody agrees to — the sentence above the button is not.
  Future<void> _removeWhatWasBuilt() async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    await _previewProjectRemoval(_fleet, project.name);
  }

  Future<void> _previewProjectRemoval(FleetModel fleet, String project) async {
    widget.deleting.letItBe();
    unawaited(widget.deleting.consider(fleet.backend, project));
    await openProjectDeletion(
      context,
      deleting: widget.deleting,
      onRemove: ({required force}) => _remove(fleet, force: force),
    );
    widget.deleting.letItBe();
  }

  /// Removes it, and refreshes the list so what is on screen is what is there.
  Future<void> _remove(FleetModel fleet, {required bool force}) async {
    await widget.deleting.remove(fleet.backend, force: force);
    final said = widget.deleting.words;
    if (said.isNotEmpty) fleet.say(said);
    if (widget.deleting.removed) await fleet.refresh();
  }

  /// Asks whether this machine can run anything, and shows what it said. Asked, never polled.
  Future<void> _checkTheMachine() async {
    widget.shell.openReadiness();
    await widget.readiness.look(_fleet.backend);
  }

  /// The person's forge login: the one the app was given, or the platform's own keychain.
  late final ForgeConnection _forges =
      widget.forges ??
      ForgeConnection(
        PlatformForgeTokens(),
        entries: _ForgesInSettings(widget.settings),
        openTerminal: widget.sessions.openTerminal,
      );

  /// The repositories this machine works on without a project, in `default`, and the projects asked
  /// again once it is put away: a repository added there is what lets work start in default.
  Future<void> _showTheDefault() async {
    await _askTheDefault();
    if (mounted) await _fleet.refresh(quietly: true);
  }

  /// Starts work in `default`: a repository named, or one worked on before, and work started on it.
  Future<void> _startInDefault() =>
      _askTheDefault(onStartWork: (repository) => _startWorkIn(defaultProject, repository: repository));

  Future<void> _askTheDefault({Future<void> Function(String repository)? onStartWork}) => showTheDefault(
    context,
    machine: _fleet.backend,
    machineName: widget.machines.current.name,
    pickAtAForge: () async {
      ({ForgeRepository repository, Forge forge})? picked;
      await showRepositories(
        context,
        _forges,
        machine: _fleet.backend,
        terminalMachine: widget.machines.current,
        machineName: widget.machines.current.name,
        usedBy: _usedBy,
        onPick: (repository, forge) => picked = (repository: repository, forge: forge),
      );
      return picked;
    },
    onStartWork: onStartWork,
  );

  Future<void> _openDevelopers(ProjectOnScreen project) async {
    if (project.name == defaultProject || !project.canBeActedOn || widget.projectAccess?.call(project.name) == null) {
      return;
    }
    await showProjectDevelopers(
      context,
      project: project.name,
      backend: _fleet.backend,
      forges: _forges,
      access: widget.projectAccess?.call(project.name),
    );
  }

  /// Why the selected project's forge cannot be opened from here, or null where it can.
  String? _itsForgeIsMissing() {
    final url = _fleet.selectedProject?.project.following?.url ?? '';
    if (url.isEmpty) return 'it is not followed from a repository';
    if (fullNameOf(url) == null) return 'its repository is not on a forge';
    if (_forges.holding(url) == null) {
      return 'its repository is on ${hostOf(url) ?? 'a forge'}, which is not set up here';
    }
    return null;
  }

  /// The selected project at its forge and on this machine: its keys, the machines it trusts,
  /// changes waiting here, and stopping work here.
  Future<void> _openItsForge() async {
    final url = _fleet.selectedProject?.project.following?.url ?? '';
    final entry = _forges.holding(url);
    final fullName = fullNameOf(url);
    if (entry == null || fullName == null) return;
    final reached = await _forges.reach(entry);
    if (reached == null) {
      _fleet.say('No token is kept for ${entry.name} on this computer. Give it one in Your forges.');
      return;
    }
    final ForgeRepository repository;
    final String login;
    try {
      repository = await reached.forge.repository(fullName);
      login = (await reached.forge.whoAmI()).login;
    } on ForgeRefused catch (refused) {
      _fleet.say(refused.words);
      return;
    }
    if (!mounted) return;
    await showProjectForge(
      context,
      MachineBinding(
        reached.forge,
        _forges.workspaceWith(repository, reached.token),
        _fleet.backend,
        machineName: widget.machines.current.name,
        login: login,
      ),
    );
  }

  /// The selected project's conversation: where it is, whether it can carry messages, and joining it.
  Future<void> _showTheMessages() async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    await showProjectMessages(
      context,
      backend: _fleet.backend,
      machine: widget.machines.current,
      project: project.project,
      forwards: _homeservers,
      settings: widget.settings,
    );
  }

  /// Shows what has been backed up of the selected project.
  ///
  /// [repository] is one of the project's; without one, the project's own.
  Future<void> _showTheBackups({String? repository}) async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    widget.shell.openBackups();
    await widget.backups.look(_fleet.backend, project.name, repository: repository);
  }

  /// Restores the mirror from the backup being considered, and says what that did.
  Future<void> _restoreTheMirror({required bool force}) async {
    await widget.backups.restore(_fleet.backend, force: force);
    final said = widget.backups.restoreWords;
    if (said.isNotEmpty) _fleet.say(said);
  }

  /// Fetches [project] now and asks its repositories' upstream; the page says what came back.
  Future<void> _checkNow(ProjectOnScreen project) async {
    final repositories = <String>[
      for (final each in project.project.repositoryStates)
        if (!each.own || project.project.repositoryStates.length == 1) each.name,
    ];
    await _check.checkNow(_fleet.backend, project.name, repositories);
    await _fleet.refresh(quietly: true);
  }

  /// Asks the upstream how far behind this project is, now.
  ///
  /// [repository] is one of the project's; without one, the project's own.
  Future<void> _syncTheUpstream({String? repository}) async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    final said = await widget.backups.syncFor(_fleet.backend, project.name, repository: repository);
    // Refreshed first: a refresh announces itself, and the answer should be said last.
    await _fleet.refresh();
    if (said.isNotEmpty) _fleet.say(said);
  }

  /// Removes the backup being considered, and says what that did.
  Future<void> _removeTheBackup() async {
    await widget.backups.remove(_fleet.backend);
    final said = widget.backups.words;
    if (said.isNotEmpty) _fleet.say(said);
  }

  /// Shows how the current machine connects out.
  Future<void> _showConnections() async {
    widget.shell.openConnections();
    // A machine just added is still being connected to: its daemon is asked once it answers.
    await _fleet.untilAsked();
    await widget.connections.lookAt(_fleet.backend, widget.machines.current.name);
  }

  /// Asks step by step what to declare, declares it, and brings its value to the machine the way
  /// the wizard settled on. What stays on the view afterwards is the way to try the value again.
  Future<void> _addAConnection({String match = ''}) async {
    final backend = _fleet.backend;
    final asked = await askForAConnection(
      context,
      match: match,
      keys: backend.sshKeys,
      check: (asked) => backend.credentialDeclare(
        kind: asked.kind,
        match: asked.match,
        id: asked.id,
        user: asked.user,
        purpose: asked.purpose,
        source: asked.source,
        fromFile: asked.fromFile,
        dryRun: true,
      ),
      pick: widget.pickAFile,
      keysAt: widget.machines.setup.sshDirectory,
      makeTheVault: _canMakeHere ? _makeTheVault : null,
      openTheVault: _canUnlockHere ? _unlockHere : null,
    );
    if (asked == null || !mounted) return;
    await widget.connections.declare(
      backend,
      kind: asked.kind,
      match: asked.match,
      id: asked.id,
      user: asked.user,
      purpose: asked.purpose,
      source: asked.source,
      fromFile: asked.fromFile,
    );
    if (!mounted || widget.connections.declared == null) return;
    switch (asked.storing) {
      case Storing.nothing:
        break;
      case Storing.sendTheKey:
        final refused = await _sendAKey(pasted: asked.key);
        if (refused != null) _fleet.say(refused);
      case Storing.onTheMachine:
        await _storeOnTheMachine();
      case Storing.inATerminal:
        await _storeInATerminal();
    }
  }

  /// Runs the declared store command on the machine, which reads the value from its own disk.
  Future<void> _storeOnTheMachine() async {
    final declared = widget.connections.declared;
    final machine = widget.machines.current;
    final command = declared == null ? null : onTheMachine(machine, declared.storeCommand, terminal: false);
    if (command == null) return;
    final failed = await widget.machines.setup.storeOnTheMachine(command, '');
    if (!mounted) return;
    _fleet.say(
      failed == null
          ? 'The key for ${declared!.connection.match} is in the vault on ${machine.name}.'
          : 'Copying the key into the vault did not work: $failed',
    );
    if (failed == null) await widget.connections.lookAt(_fleet.backend, machine.name);
  }

  /// Sets up a connection for the address being followed, in the machine's connections — where its
  /// value is then stored — rather than inventing one here.
  Future<void> _setUpTheConnectionOfTheFollow() async {
    final url = widget.following.url.trim();
    await _showConnections();
    if (!mounted) return;
    await _addAConnection(match: url);
  }

  /// Stores the value the check found missing, by the command it named, in a terminal there.
  Future<void> _storeWhatTheCheckNamed() async {
    final check = widget.following.check;
    final machine = widget.machines.current;
    final command = check == null ? null : onTheMachine(machine, check.storeCommand, terminal: true);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Store the value for ${widget.following.url.trim()}',
      explanation:
          'Type or paste the value into the terminal. It goes straight to the machine '
          'and never through this program, and nothing here keeps it. Then follow it again.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
  }

  /// Whether a value can be stored on the current machine from here: its own `porelo` is reachable.
  bool get _storesHere => onTheMachine(widget.machines.current, const <String>['porelo'], terminal: false) != null;

  /// Stores the declared value by typing it into a terminal on the machine, then reads again.
  Future<void> _storeInATerminal() async {
    final declared = widget.connections.declared;
    final machine = widget.machines.current;
    final command = declared == null ? null : onTheMachine(machine, declared.storeCommand, terminal: true);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Store ${declared!.connection.match} on ${machine.name}',
      explanation:
          'Type or paste the value into the terminal. It goes straight to the machine '
          'and never through this program, and nothing here keeps it.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!mounted) return;
    await widget.connections.lookAt(_fleet.backend, machine.name);
  }

  /// Sends a key to the declared store command on its standard input: a file of this computer's,
  /// read at the moment it is sent, or what was pasted. Held for that moment and nowhere after.
  /// Answers why nothing was stored, or null once it was.
  Future<String?> _sendAKey({String? file, String? pasted}) async {
    final declared = widget.connections.declared;
    final machine = widget.machines.current;
    final command = declared == null ? null : onTheMachine(machine, declared.storeCommand, terminal: false);
    if (command == null) return 'This machine is not one keys are sent to from here.';
    String value;
    try {
      // Read at once and whole: a key is a few hundred bytes, and nothing else waits on it.
      value = file != null ? File(file).readAsStringSync() : pasted ?? '';
    } on FileSystemException catch (ex) {
      return 'That key could not be read: ${ex.osError?.message ?? ex.message}';
    }
    if (declared!.connection.kind == 'SSH_KEY') {
      final wrong = notAPrivateKey(value);
      if (wrong != null) return wrong;
    } else if (value.trim().isEmpty) {
      return 'There is nothing in it to send.';
    }
    final failed = await widget.machines.setup.storeOnTheMachine(command, value.endsWith('\n') ? value : '$value\n');
    if (!mounted) return null;
    if (failed != null) {
      _fleet.say('Storing the key did not work: $failed');
      return 'Storing the key did not work: $failed';
    }
    _fleet.say('The key for ${declared.connection.match} is stored on ${machine.name}.');
    await widget.connections.lookAt(_fleet.backend, machine.name);
    return null;
  }

  /// Makes the current machine's vault by a passphrase chosen in a terminal there, then asks the
  /// machine whether it is there — the terminal's exit code is not the verdict.
  Future<void> _makeTheVault() async {
    final machine = widget.machines.current;
    final command = makeCommandFor(machine);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Make the vault on ${machine.name}',
      explanation:
          'Choose a passphrase and type it twice. It goes straight to the machine and '
          'never through this program, and nothing here keeps it. The vault is open afterwards, '
          'so this device can be enrolled next.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!mounted) return;
    await widget.vault.lookAt(_fleet.backend, machine.name);
  }

  /// Whether the current machine's own `porelo` can be reached for a terminal.
  bool get _canUnlockHere => unlockCommandFor(widget.machines.current) != null;

  /// Whether the current machine's vault can be made here: never a rented server's, which its setup makes.
  bool get _canMakeHere => makeCommandFor(widget.machines.current) != null;

  /// Grants what [credential] names, then asks the vault again: the grant is kept there.
  Future<void> _grant(Credential credential) async {
    final machine = widget.machines.current;
    await showGranting(context, Granting(_fleet.backend, machine, credential.name));
    if (!mounted) return;
    await widget.vault.lookAt(_fleet.backend, machine.name);
  }

  /// Opens the current machine's vault by its passphrase, in a terminal on that machine, then asks
  /// the machine whether it is open — the terminal's exit code is not the verdict.
  Future<void> _unlockHere() async {
    await _unlockMachine(widget.machines.current);
  }

  VoidCallback? _unlockFor(Machine machine) =>
      unlockCommandFor(machine) == null ? null : () => unawaited(_unlockMachine(machine));

  Future<void> _unlockMachine(Machine machine) async {
    final fleet = widget.machines.of(machine);
    final List<String>? command;
    try {
      command = unlockCommandFor(machine);
    } on FormatException catch (error) {
      _fleet.say(error.message);
      return;
    } on HostFilesRefused catch (error) {
      _fleet.say(error.message);
      return;
    }
    if (command == null) return;
    await unlockInATerminal(context, machine: machine, command: command, open: widget.sessions.openTerminal);
    if (!mounted) return;
    await widget.vault.lookAt(fleet.backend, machine.name);
    await fleet.refresh(quietly: true);
  }

  Future<void> _askKeepResolved() async {
    int? value = widget.settings.keepResolvedMinutes;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final minutes = value;
          final valid = minutes != null && minutes >= 0;
          return AlertDialog(
            title: const Text('Keep resolved rows for'),
            content: SizedBox(
              width: Sizes.dialogNarrow,
              child: TextFormField(
                initialValue: '${widget.settings.keepResolvedMinutes}',
                keyboardType: TextInputType.number,
                onChanged: (text) => update(() => value = int.tryParse(text)),
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  helperText: '0 removes rows immediately.',
                  errorText: valid ? null : 'Enter a whole number of minutes, zero or more.',
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: valid ? () => Navigator.pop(context, minutes) : null, child: const Text('Keep')),
            ],
          );
        },
      ),
    );
    if (mounted && minutes != null) await widget.settings.setKeepResolvedMinutes(minutes);
  }

  /// The person's own repositories on a forge: made a project, and this machine bound to one.
  /// A project from a repository the person has: their forges, or the one forge's repositories
  /// straight away where there is only one (walk 10: forges are a place of their own).
  void _fromARepository() => unawaited(() async {
    await _forges.readList();
    if (_forges.entries.length == 1) return _openTheForge(_forges.entries.single);
    widget.shell.goTo(Section.forges);
    // None yet: the first is set up at once, and its repositories shown once it connects.
    if (_forges.entries.isNotEmpty || !mounted) return;
    await showForgeForm(context, _forges, onFollowByAddress: () => unawaited(_followARepository()));
    if (_forges.connected && mounted) widget.shell.goTo(Section.forge);
  }());

  /// The forges set up on this computer.
  void _showTheForges() => widget.shell.goTo(Section.forges);

  /// Opens [entry]'s repositories as a page.
  Future<void> _openTheForge(ForgeEntry entry) async {
    widget.shell.goTo(Section.forge);
    if (_forges.current?.id != entry.id || !_forges.connected) await _forges.choose(entry);
  }

  /// Every forge set up here, as a page beside Machines and Projects.
  Widget _forgesPage() =>
      _opened() ?? ForgesPage(forges: _forges, usedBy: _usedBy, onOpen: (entry) => unawaited(_openTheForge(entry)));

  /// One forge's repositories, as a page.
  Widget _forgePage() =>
      _opened() ??
      ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          for (final machine in widget.machines.all) widget.machines.of(machine),
        ]),
        builder: (context, _) => ForgePage(
          forges: _forges,
          usedBy: _usedBy,
          usedOn: _machinesWorkingOn,
          inDefault: (fullName) => _fleet.projects
              .where((each) => each.name == defaultProject)
              .any(
                (each) =>
                    each.project.repositoryStates.any((repository) => fullNameOf(repository.upstream) == fullName),
              ),
          onDefaultChanged: () => unawaited(_fleet.refresh(quietly: true)),
          machine: _fleet.reachability == Reachability.connected ? _fleet.backend : null,
          terminalMachine: widget.machines.current,
          machineName: widget.machines.current.name,
          onStartWork: _startWorkIn,
        ),
      );

  /// The watched machines on which the repository called [fullName] is worked on, or holds the
  /// settings of a project: by name, nothing else (walk 10).
  List<String> _machinesWorkingOn(String fullName) => <String>[
    for (final machine in widget.machines.all)
      if (widget.machines
          .of(machine)
          .projects
          .any(
            (each) =>
                fullNameOf(each.project.following?.url ?? '') == fullName ||
                each.project.repositoryStates.any((repository) => fullNameOf(repository.upstream) == fullName),
          ))
        machine.name,
  ];

  /// The repositories of the projects the watched machines follow on [entry]'s forge: what keys
  /// were given there, which removing the entry would leave without a way to take them off.
  List<String> _usedBy(ForgeEntry entry) => <String>{
    for (final machine in widget.machines.all)
      for (final project in widget.machines.of(machine).projects)
        for (final url in <String>[
          project.project.following?.url ?? '',
          for (final each in project.project.repositoryStates) each.upstream,
        ])
          if (hostOf(url) == entry.address) ?fullNameOf(url),
  }.toList()..sort();

  /// Follows a repository in the machine's place — the only way a project comes to a machine.
  Future<void> _followARepository() async {
    widget.following.startOn(_fleet.backend);
    widget.shell
      ..goTo(Section.projects)
      ..openProjectFollowing();
  }

  /// Puts it away; a project that is now followed is then the one selected.
  Future<void> _doneFollowing(bool taken) async {
    final name = widget.following.name.trim();
    widget.shell.close();
    widget.following.letItBe();
    if (!taken) return;
    await _fleet.refresh();
    _fleet.selectProject(name);
    // The project it made, opened on its page, as Projects opens one.
    widget.shell.goTo(Section.project);
  }

  /// Builds a project's environment without starting anything, at a depth somebody chooses.
  Future<void> _prepareTheProject() async {
    final project = _fleet.selectedProject;
    if (project == null || !project.canBeActedOn) return;
    final depth = await askHowMuchToBuild(context, project: project.name);
    if (depth == null || !mounted) return;

    final operation = widget.operations.run(
      title: 'Build the environment for ${project.name}',
      machine: widget.machines.current.name,
      output: _fleet.backend.buildEnvironment(project.project.name, rebuild: depth.name),
    );
    widget.shell.openOperation(operation.id);
    // A built image changes `preparedState`, which the project card draws.
    await _fleet.refresh();
  }

  /// Shows what this machine can authenticate against, and where each credential belongs.
  Future<void> _showTheProviders() async {
    widget.authentication.letItBe();
    widget.shell.openProviders();
    await widget.authentication.look(_fleet.backend);
  }

  /// Imports a credential an agent already holds on the machine. **No secret crosses doing it.**
  Future<void> _import(String? agent) async {
    await widget.authentication.importFor(_fleet.backend, agent: agent);
  }

  /// Opens what the selected project's work may reach.
  ///
  /// With [repository], what that repository adds on top of what every repository gets.
  Future<void> _openEgress({String? repository}) async {
    final project = _fleet.selectedProject?.project;
    if (project == null) return;
    widget.shell.openEgress();
    await widget.egress.lookAt(_fleet.backend, project, repository: repository);
  }

  /// Gives a piece of work something to read by, or takes it away. Nothing about its identity
  /// moves.
  Future<void> _nameTheWork(Task task) async {
    final caption = await askWhatItReadsAs(context, task: task);
    if (caption == null || !mounted) return;
    final answer = await _fleet.backend.labelTask(task.name, label: caption);
    if (!mounted) return;
    _fleet.say(answer.words);
    await _fleet.refresh();
  }

  /// Opens the emergency stop for the machine being acted on, having first asked what it would
  /// stop. Agreeing is a second, separate act.
  Future<void> _stopEverything() async {
    widget.stopping.letItBe();
    unawaited(widget.stopping.consider(_fleet.backend));
    await openEmergencyStop(
      context,
      stopping: widget.stopping,
      onStopEverything: () => widget.stopping.stopEverything(_fleet.backend),
    );
    widget.stopping.letItBe();
  }

  /// The same stop, on every machine at once.
  Future<void> _stopEverywhere() => openEmergencyStopEverywhere(
    context,
    machines: <String, FleetBackend>{
      for (final machine in widget.machines.all) machine.name: widget.machines.of(machine).backend,
    },
  );

  /// Shows what the vault holds, asked every time it is opened.
  Future<void> _showTheVault() async {
    widget.shell.openVault();
    await widget.vault.lookAt(_fleet.backend, widget.machines.current.name);
  }

  /// Which machine, and in which state, the vault's button was last asked about.
  String _vaultAskedFor = '';

  /// Asks the machine in the title about its store whenever it becomes the one shown or answers
  /// again, so the button beside the stop is never a guess.
  void _keepTheVaultButtonTrue(Machine machine, FleetModel fleet) {
    final asking = '${machine.name}/${fleet.reachability.name}';
    if (asking == _vaultAskedFor) return;
    _vaultAskedFor = asking;
    if (fleet.reachability != Reachability.connected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.vault.lookAt(fleet.backend, machine.name));
    });
  }

  /// Enrolls this device, opens the store with it, or shuts it: the button's act, or a menu's.
  Future<void> _actOnTheVault(VaultAct act) async {
    final vault = widget.vault;
    final backend = _fleet.backend;
    String devicesSaid() => vault.devices.problem ?? vault.devices.said ?? '';
    await showDialog<void>(
      context: context,
      builder: (context) => switch (act) {
        VaultAct.enroll => EnrollDialog(
          storage: vault.devices.store.storage,
          suggested: _hostName(),
          onEnroll: (name) => vault.devices.enroll(backend, name),
          answer: devicesSaid,
        ),
        VaultAct.open => OpenDialog(
          onOpen: (minutes) async {
            await vault.devices.unlock(backend, minutes: minutes);
            await vault.look(backend);
          },
          answer: devicesSaid,
        ),
        VaultAct.shut => ShutDialog(
          onShut: () => vault.lock(backend),
          answer: () => vault.problem ?? vault.shut?.words ?? '',
        ),
      },
    );
  }

  static String _hostName() {
    try {
      return Platform.localHostname;
    } on Object {
      return '';
    }
  }

  /// Shows what agents this machine has, asked every time it is opened.
  Future<void> _showAgents() async {
    widget.shell.openAgents();
    await widget.inventory.load(_fleet.backend);
  }

  /// Stops watching the machine being acted on, and goes back to what needs a person.
  /// What forgetting a machine does, said before it is done.
  static const _forgetting =
      'This interface stops watching it and takes down the tunnel it raised to it. Nothing on the machine '
      'changes: its Porelo, its work and its vault stay as they are, and Watch another machine… adds it again.';

  Future<void> _forget() async {
    if (widget.machines.all.length < 2) return;
    final machine = widget.machines.current;
    if (machine.kind == 'host') {
      final takeDown = _hostCommands(machine).singleWhere((command) => command.id == 'machine.takeDown');
      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('host-forget-warning'),
          title: Text('Forget ${machine.name}?'),
          content: SizedBox(
            width: Sizes.dialogMedium,
            child: DialogScroll(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(_forgetting),
                  const SizedBox(height: Space.normal),
                  const Text(
                    'The server keeps running and billing at the provider. '
                    'To add it back, use Put this project on a server… again; it finds the existing server by its tag.',
                  ),
                  if (takeDown.unavailable != null)
                    Text('Take this server down is unavailable: ${takeDown.unavailable}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: takeDown.available ? () => Navigator.pop(context, 'down') : null,
              child: Text(takeDown.label),
            ),
            FilledButton(
              key: const Key('forget-it'),
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Forget it'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (decision == 'down') takeDown.run();
      if (decision != 'remove') return;
    }
    final setup = widget.machines.setup;
    // Only what the wizard wrote is offered, and only ever offered: an entry somebody wrote or
    // changed by hand is theirs, and a key another entry uses would break that one.
    final written = machine.needsATunnel ? setup.entryWrittenFor(machine.host) : null;
    if (written == null && machine.kind != 'host') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Forget ${machine.name}?'),
          content: const SizedBox(width: Sizes.dialogMedium, child: Text(_forgetting)),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
              key: const Key('forget-it'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Forget it'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    var removeEntry = false;
    if (written != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Forget ${machine.name}?'),
            content: SizedBox(
              width: Sizes.dialogMedium,
              child: DialogScroll(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(_forgetting),
                    const SizedBox(height: Space.normal),
                    CheckboxListTile(
                      key: const Key('forget-host-entry'),
                      contentPadding: EdgeInsets.zero,
                      value: removeEntry,
                      onChanged: (value) => setState(() => removeEntry = value ?? false),
                      title: Text('Also remove Host ${machine.host} from ~/.ssh/config'),
                      subtitle: const Text('The entry setting it up wrote; the file as it was is kept.'),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(
                key: const Key('forget-it'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Forget it'),
              ),
            ],
          ),
        ),
      );
      if (yes != true) return;
    }
    // Back to the list of machines, where it was removed from (walk 9): never to a
    // page of the machine that is gone.
    widget.shell.goTo(Section.machines);
    await widget.machines.forget(machine);
    if (written == null || !removeEntry) return;
    widget.operations.run(
      title: 'Forget ${machine.name}',
      machine: machine.name,
      output: () async* {
        if (removeEntry) yield await setup.removeHostEntry(machine.host);
      }(),
    );
  }

  /// Says what this is and what every machine it watches runs.
  void _showAbout() => showAboutDialog(
    context: context,
    applicationName: productName,
    applicationVersion: _version,
    applicationLegalese:
        'The interface to Porelo: agent work in guarded containers, on '
        'machines you watch from here.',
    children: <Widget>[
      const SizedBox(height: Space.normal),
      for (final machine in widget.machines.all)
        Text(
          '${machine.name}: ${switch (widget.machines.of(machine).info) {
            final info? => '${info.product} ${info.version}',
            null => 'not connected',
          }}',
        ),
    ],
  );

  /// Starts work from a recurring job somebody named.
  Future<void> _startFromTemplate(Template job) async {
    final project = _fleet.selectedProject?.project;
    if (project == null) return;
    // Open at once and read behind it: waiting for the machine first left the press unanswered.
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.openFrom(_fleet.backend, project, job));
    await _offerToStart();
  }

  /// Starts work in the selected project.
  Future<void> _startWork({String? repository}) async {
    final project = _fleet.selectedProject?.project;
    if (project == null) return;
    // In default, work starts on a repository named first: the one way, wherever it is asked for.
    if (project.name == defaultProject) return _startInDefault();
    // Open at once and read behind it: waiting for the machine first left the press unanswered.
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.open(_fleet.backend, project, repository: repository));
    await _offerToStart();
  }

  /// The other machines where work of the project called [name] runs, as each last said.
  List<String> _runningElsewhere(String name) => <String>[
    for (final machine in widget.machines.all)
      if (machine != widget.machines.current &&
          widget.machines.of(machine).tasks.any((task) => task.running && task.project == name))
        machine.name,
  ];

  /// Starts work in the project called [name], once the machine lists it: what binding a machine
  /// from a repository leads to.
  Future<void> _startWorkIn(String name, {String? repository}) async {
    Project? listed() => _fleet.projects.where((each) => each.project.name == name).firstOrNull?.project;
    // Asked of the machine first only when it is not known yet: a round trip before the form opened
    // was a pause a person noticed.
    final known = listed();
    if (known == null || (repository != null && !known.repositories.contains(repository))) {
      await _fleet.refresh(quietly: true);
    } else {
      unawaited(_fleet.refresh(quietly: true));
    }
    final project = listed();
    if (project == null || !mounted) return;
    // The project the work starts in is the one shown in the tree: a project made from a repository
    // appeared there unselected, and the person looked for it (walk 8).
    if (name != defaultProject) {
      _fleet.selectProject(name);
      widget.shell.goTo(Section.project);
    }
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.open(_fleet.backend, project));
    if (repository != null) widget.starting.chooseRepository(repository);
    await _offerToStart();
  }

  /// Continues a finished unattended run, with what it was asked to do last time in the box.
  Future<void> _continueTheWork([Task? work]) async {
    final task = work ?? _fleet.selectedTask;
    final project = (task == null ? null : _projectOf(task))?.project ?? _fleet.selectedProject?.project;
    if (task == null || project == null) return;
    unawaited(widget.starting.continueFrom(_fleet.backend, project, task));
    await _offerToStart();
  }

  Future<void> _offerToStart() async {
    await openStartWork(
      context,
      starting: widget.starting,
      onStart: _beginTheRun,
      onKeep: _keepAsTemplate,
      onStoreTheCredential: onTheMachineAsWritten(widget.machines.current, 'porelo') == null
          ? null
          : _storeTheCredentialToStart,
      onLogIn: onTheMachineAsWritten(widget.machines.current, 'porelo') == null ? null : _logInWithTheAgent,
      onOpenWithThisDevice: widget.vault.devices.enrolledHere ? _openWithThisDeviceToStart : null,
      onGrant: _grantToStart,
      onFixInATerminal: onTheMachine(widget.machines.current, _aShell, terminal: true) == null
          ? null
          : _fixTheUpstreamToStart,
    );
    widget.starting.close();
  }

  /// A login shell on the machine, for a person to run what the machine named.
  static const List<String> _aShell = <String>['bash', '-l'];

  /// Opens a shell on the machine whose upstream refused its key, where the person runs the command
  /// the machine named, then asks the machine again whether work can start: the fix is its to see.
  Future<void> _fixTheUpstreamToStart() async {
    final machine = widget.machines.current;
    final command = onTheMachine(machine, _aShell, terminal: true);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Fix the repository’s access on ${machine.name}',
      explanation:
          'Run the command the start named. Whatever it asks for goes straight to the machine and '
          'never through this program. Close the terminal when it is done.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!mounted) return;
    await widget.starting.askAgain();
  }

  /// Grants what starting said needs a grant, in a browser, then asks the machine again whether work
  /// can start: the grant is the machine's to confirm.
  Future<void> _grantToStart(String entry) async {
    await showGranting(context, Granting(_fleet.backend, widget.machines.current, entry));
    await widget.starting.askAgain();
  }

  /// Opens the locked vault starting was refused on, with this device and for as long as the person
  /// chooses — then asks the machine again whether work can start.
  Future<void> _openWithThisDeviceToStart() async {
    await _actOnTheVault(VaultAct.open);
    await widget.starting.askAgain();
  }

  /// Stores the credential starting said is missing, by the line the machine names for its
  /// provider, in a terminal there — then asks the machine again whether work can start.
  Future<void> _storeTheCredentialToStart() async {
    final readiness = widget.starting.readiness;
    final machine = widget.machines.current;
    if (readiness == null) return;
    // The machine's own command, as arguments, where it gives one.
    final named = onTheMachine(machine, readiness.storeCommand, terminal: true);
    if (named != null) {
      await runInATerminal(
        context,
        title: 'Store ${readiness.credential.isEmpty ? 'the credential' : readiness.credential}',
        explanation:
            'Type or paste it into the terminal. It goes straight to the machine and never '
            'through this program, and nothing here keeps it.',
        machine: machine,
        command: named,
        open: widget.sessions.openTerminal,
      );
      if (!mounted) return;
      await widget.starting.askAgain();
      return;
    }
    // A Porelo older than the field: the provider's line, run as the machine wrote it.
    final Providers providers;
    try {
      providers = await _fleet.backend.providers();
    } on Exception catch (ex) {
      // Pressed from a dialog nobody awaits: said here, or it reaches nobody.
      _fleet.say('The machine could not say how to store a credential for ${readiness.provider}: $ex');
      return;
    }
    final provider = providers.providers.where((each) => each.name == readiness.provider).firstOrNull;
    final command = provider == null ? null : onTheMachineAsWritten(machine, provider.storeCommand);
    if (!mounted) return;
    if (command == null) {
      _fleet.say('The machine names no way to store a credential for ${readiness.provider}.');
      return;
    }
    await runInATerminal(
      context,
      title: 'Store the credential for ${provider!.label.isEmpty ? provider.name : provider.label}',
      explanation:
          'Type or paste it into the terminal. It goes straight to the machine and never '
          'through this program, and nothing here keeps it.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!mounted) return;
    await widget.starting.askAgain();
  }

  /// Runs [agent]'s own login on the machine, through Porelo, in a terminal there: its page is offered
  /// as a link to open here, and its reply to `localhost` is forwarded while the terminal is open.
  /// Then asks the machine again whether work can start.
  Future<void> _logInWithTheAgent(Agent agent) => _logIn(
    agent,
    askAgain: widget.starting.askAgain,
    stillMissing: () => widget.starting.needsASignIn,
    from: 'the start form',
  );

  /// Opens the wizard that starts the agent each repository of [name] names, on the machine acted on.
  Future<void> _startTheAgents(String name) async {
    await _fleet.refresh(quietly: true);
    final project = _fleet.projects.where((each) => each.project.name == name).firstOrNull?.project;
    if (project == null || !mounted) return;
    final starting = _startingAgents;
    unawaited(starting.open(_fleet.backend, project));
    await openStartAgents(
      context,
      starting: starting,
      onLogIn: onTheMachineAsWritten(widget.machines.current, 'porelo') == null
          ? null
          : (agent) => _logIn(
              agent,
              askAgain: starting.askAgain,
              stillMissing: () => starting.signInsNeeded.any((each) => each.name == agent.name),
              from: 'the wizard',
            ),
    );
  }

  /// Runs [agent]'s own login on the machine, then asks again through [askAgain] whether work can
  /// start; [stillMissing] says whether it still has nothing to sign in with, and [from] where to try again.
  Future<void> _logIn(
    Agent agent, {
    required Future<void> Function() askAgain,
    required bool Function() stillMissing,
    required String from,
  }) async {
    final machine = widget.machines.current;
    // The machine's own command; spelled here only for a Porelo that declared a login before it named one.
    final command = onTheMachine(
      machine,
      agent.loginCommand.isNotEmpty ? agent.loginCommand : <String>['porelo', 'vault', 'login', agent.name],
      terminal: true,
    );
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Log in with ${agent.label.isEmpty ? agent.name : agent.label}',
      explanation:
          'This runs the agent’s own login on ${machine.name}. It shows a link: open it in '
          'your browser and sign in. Then the page either hands the answer back here by itself, or '
          'shows a code to paste into the terminal below. What the login gives goes into the vault '
          'there, and never through this program.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
      forwardsALoginReply: true,
      stillWorking:
          'Still working on ${machine.name}. The first sign-in builds '
          '${agent.label.isEmpty ? agent.name : agent.label}’s image, which takes a few minutes and may '
          'print nothing for a while. Then its own sign-in starts here.',
      cancel: 'Cancel the sign-in',
      whatCameOfIt: () async {
        await askAgain();
        final label = agent.label.isEmpty ? agent.name : agent.label;
        return stillMissing()
            ? 'Nothing was stored for $label on ${machine.name}. What the terminal printed says why; '
                  'sign in again from $from.'
            : 'Signed in to $label: the credential is stored on ${machine.name}. You can close this.';
      },
    );
    if (!mounted) return;
    await askAgain();
  }

  /// Keeps what is on screen as a recurring job.
  void _keepAsTemplate() {
    final job = widget.starting.asTemplate;
    if (job == null) return;
    unawaited(widget.templates.keep(job));
  }

  /// Runs it, and hands the stream to the session record rather than to this view.
  void _beginTheRun() {
    final starting = widget.starting;
    final project = starting.project?.name ?? '';
    final named = starting.name.trim();
    // Somebody who chose to work by hand is taken into the work once it is up, not left at a log.
    final byHand = starting.mode == Mode.shell || starting.mode == Mode.agent;
    final runningBefore = <String>{
      for (final task in _fleet.tasks)
        if (task.project == project && task.running) task.name,
    };
    final operation = widget.operations.run(
      title: starting.title,
      machine: widget.machines.current.name,
      output: starting.begin(_fleet.backend),
    );
    if (starting.mode == Mode.unattended) {
      _runs[operation.id] = UnattendedRun(
        machine: widget.machines.current,
        fleet: _fleet,
        project: project,
        named: named,
        operation: operation,
        operations: widget.operations,
      );
    }
    widget.shell.openOperation(operation.id);
    if (byHand) unawaited(_workInItOnceUp(operation, project, named, runningBefore));
  }

  /// Opens the session on the work a start brought up, once the start has finished well: the one
  /// of the name it was given, or else the one of that project that was not running before.
  Future<void> _workInItOnceUp(Operation operation, String project, String named, Set<String> runningBefore) async {
    final ended = Completer<void>();
    void check() {
      if (!operation.running && !ended.isCompleted) ended.complete();
    }

    widget.operations.addListener(check);
    check();
    await ended.future;
    widget.operations.removeListener(check);
    if (!mounted || operation.failed) return;
    await _fleet.refresh(quietly: true);
    if (!mounted) return;
    final up = _fleet.tasks.where((task) => task.project == project && task.running).toList();
    final task =
        (named.isEmpty ? null : up.where((each) => each.task == named).firstOrNull) ??
        up.where((each) => !runningBefore.contains(each.name)).firstOrNull;
    if (task != null) _openSession(task);
  }

  /// Changes what running work does with a blocked connection. **It opens nothing.**
  Future<void> _enforceOnTheWork() async {
    final task = _fleet.selectedTask;
    if (task == null) return;
    final chosen = await askHowToEnforce(context, task: task.name, now: task.clearance);
    if (chosen == null || !mounted) return;
    final said = await _fleet.backend.setClearance(task.name, chosen.name);
    // Refreshed first, then said: a refresh announces itself.
    await _fleet.refresh();
    _fleet.say(whatEnforcementDid(said, task.name));
  }

  /// Shows whom the work may talk to, on its own machine, where each peer is moderated and a
  /// person can write to one.
  void _talkForTheWork(Task task) => unawaited(
    showPeers(
      context,
      backend: _fleet.backend,
      task: task,
      mailboxes: _fleet.mailboxes,
      sameProject: <String>{
        for (final each in _fleet.tasks)
          if (each.project == task.project) each.name,
      },
    ),
  );

  /// Hands a file chosen on this computer to running work, in parts, and says what came of it.
  Future<void> _handInTo(Task task) async {
    final path = await widget.pickAFile(title: 'A file to hand to ${task.name}');
    if (path == null || !mounted) return;
    final backend = _fleet.backend;
    await _handing.give(backend, task, path);
    if (!mounted) return;
    _fleet.say(_handing.said ?? '');
    unawaited(_handIns.look(backend, task.name));
  }

  /// Brings [task]'s repository at the gate up to its source, and says what moved and whether its
  /// agent was told.
  Future<void> _refreshFromItsSource(Task task) async {
    String said;
    try {
      said = (await _fleet.backend.refreshTask(task.name)).wordsFor(task.name);
    } on VarlinkException catch (refusal) {
      said = '${task.name} was not brought up to its source: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (lost) {
      said = 'Lost contact with the machine: ${lost.message}';
    } on FeatureNotSupported catch (older) {
      said = '$older';
    }
    if (mounted) _fleet.say(said);
  }

  /// Takes back a file the work was handed, chosen from what it holds.
  Future<void> _takeBackFrom(Task task) async {
    final files = task.files ?? const <HandedFile>[];
    final name = await showDialog<String>(
      context: context,
      builder: (asked) => SimpleDialog(
        title: Text('Take a file back from ${task.name}'),
        children: <Widget>[
          for (final file in files)
            SimpleDialogOption(
              key: Key('take back ${file.name}'),
              onPressed: () => Navigator.of(asked).pop(file.name),
              child: Text('${file.name}, ${HandingIn.inWords(file.bytes)}, by ${file.from}'),
            ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final backend = _fleet.backend;
    await _handing.takeBack(backend, task, name);
    if (!mounted) return;
    _fleet.say(_handing.said ?? '');
    unawaited(_handIns.look(backend, task.name));
  }

  /// A person's own words straight into the work's inbox, where its agent reads them.
  Future<void> _tellTheWork(Task task) async {
    final words = await askForWords(
      context,
      title: 'Write to the agent of ${task.name}',
      explain:
          'It goes straight into its inbox, where its agent reads it, marked as written by a person. '
          'It never leaves this machine, so it is neither signed nor filtered.',
      label: 'What you want it to know',
      confirm: 'Put it in its inbox',
      required: true,
    );
    if (words == null || words.isEmpty || !mounted) return;
    try {
      await _fleet.backend.tell(task.name, words);
      _fleet.say('Written into the inbox of ${task.name}. Its agent reads it there.');
    } on VarlinkException catch (refusal) {
      _fleet.say(
        refusal.simpleName == 'NoSuchTask'
            ? '${task.name} is not on this machine any more, so nothing was written.'
            : 'The machine refused to write it: ${refusal.simpleName}.',
      );
    } on VarlinkDisconnected catch (ex) {
      _fleet.say('Lost contact before it was written: ${ex.message}');
    }
  }

  /// Takes a name back from work that is already running, previewed every time.
  Future<void> _narrowTheWork() async {
    final task = _fleet.selectedTask;
    if (task == null) return;
    widget.narrowing.open(task);
    await openNarrowing(
      context,
      narrowing: widget.narrowing,
      onConsider: () => widget.narrowing.consider(_fleet.backend),
      onApply: () => widget.narrowing.apply(_fleet.backend),
    );
    final said = widget.narrowing.words;
    if (said.isNotEmpty) _fleet.say(said);
    widget.narrowing.close();
  }

  /// Lets the selected work reach something it could not reach before.
  Future<void> _widenTheWork() async {
    final task = _fleet.selectedTask;
    if (task == null) return;
    widget.widening.open(task);
    await openWidening(
      context,
      widening: widget.widening,
      onConsider: () => widget.widening.consider(_fleet.backend),
      onApply: () => widget.widening.apply(_fleet.backend),
    );
    widget.widening.close();
  }

  /// Opens one waiting push, and reads what it contains.
  Future<void> _look(PendingPush push) async {
    widget.shell.openReview();
    await widget.gate.look(_fleet.backend, push);
  }

  /// Forwards the push being judged, onto a branch somebody names.
  Future<void> _approve() async {
    final push = widget.gate.looking;
    if (push == null) return;
    final offered = await _branchesFor(push);
    if (!mounted) return;
    final branch = await askWhichBranch(
      context,
      subject: push.subject,
      toOrigin: widget.gate.project?.name == defaultProject,
      branches: offered?.branches ?? const <String>[],
      defaultBranch: offered?.defaultBranch,
    );
    if (branch == null) return;
    final said = await widget.gate.approve(_fleet.backend, branch);
    if (said.isNotEmpty) _fleet.say(said);
    if (widget.gate.problem == null) widget.shell.openGate();
    // What waits is read again at once: the project's badge said "1" after the push was through
    // (walk 8).
    unawaited(_fleet.refresh(quietly: true));
  }

  /// The host key fingerprints the first forge kept here publishes for itself; none where none
  /// answers.
  Future<List<String>> _publishedHostKeys() async {
    for (final entry in _forges.entries) {
      try {
        final reached = await _forges.reach(entry);
        if (reached != null) return await reached.forge.hostKeyFingerprints();
      } on Object {
        continue;
      }
    }
    return const <String>[];
  }

  /// The branches of the repository [push] waits in, and its default, from the forge kept here that
  /// reaches it; null where its upstream is at no forge a token here reaches, and a branch is
  /// then typed, checked before it is sent.
  Future<({List<String> branches, String defaultBranch})?> _branchesFor(PendingPush push) async {
    final upstream = widget.gate.project?.repositoryStates
        .where((each) => each.name == push.repository)
        .firstOrNull
        ?.upstream;
    final there = upstream == null ? null : onGitHub(upstream);
    if (there == null) return null;
    for (final entry in _forges.entries) {
      try {
        final reached = await _forges.reach(entry);
        if (reached == null) continue;
        final repository = await reached.forge.repository(there);
        return (branches: await reached.forge.branches(there), defaultBranch: repository.defaultBranch);
      } on Object {
        continue;
      }
    }
    return null;
  }

  /// Drops the request being judged, with why in the person's words for the task it came from.
  Future<void> _reject() async {
    final reason = await askForWords(
      context,
      title: 'Drop the request',
      explain:
          'The work stays in the mirror; only the request is gone. The task it came from is told '
          'in its inbox, with your words when you give them, so its agent knows why.',
      label: 'Why, for its agent (optional)',
      confirm: 'Drop it',
    );
    if (reason == null || !mounted) return;
    final said = await widget.gate.reject(_fleet.backend, reason: reason);
    if (said.isNotEmpty) _fleet.say(said);
    if (widget.gate.problem == null) widget.shell.openGate();
    // What waits is read again at once: the project's badge said "1" after the push was through
    // (walk 8).
    unawaited(_fleet.refresh(quietly: true));
  }

  /// A start asked for in the dialog, recorded as one from the menu is. The dialog shows what came
  /// back; the record is what keeps a failure once the dialog is closed.
  Future<Started> _startAskedInTheDialog(Machine machine) async {
    final started = await widget.machines.startPoreloOn(machine);
    widget.operations.run(
      title: 'Start Porelo on ${machine.host}',
      machine: machine.name,
      output: _saidByAStart(machine, started),
    );
    return started;
  }

  Stream<String> _saidByAStart(Machine machine, Started started) async* {
    yield Tunnels.startCommandFor(machine).join(' ');
    yield started.words;
    if (!started.went) throw FailedSaying(started.words);
  }

  /// The second wizard: another user that runs work on a machine prepared before, watched as a
  /// machine of its own — its own daemon, tasks and vault.
  Future<void> _addAUser() => _addAMachine(only: MachineKind.newUser);

  /// Asks which user a new machine runs work as: the one Porelo's setup script creates there.
  Future<void> _askTheWorkUser() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _WorkUserDialog(current: widget.settings.workUser),
    );
    if (name != null) await widget.settings.setWorkUser(name);
  }

  /// Asks for another machine to watch, starts watching it, and goes there.
  Future<void> _addAMachine({MachineKind? only}) async {
    var thenConnections = false;
    final machine = await askForAMachine(
      only: only,
      context,
      taken: widget.machines.all.map((each) => each.name),
      trying: widget.machines.tryMachine,
      starting: _startAskedInTheDialog,
      hostKeys: widget.machines.hostKeys,
      setup: widget.machines.setup,
      workUser: widget.settings.workUser,
      draft: widget.settings.setupDraft,
      remember: widget.settings.setSetupDraft,
      openTerminal: widget.sessions.openTerminal,
      countKeyslots: widget.machines.keyslotsOn,
      socketAt: widget.machines.socketAt,
      whyNotLoggedIn: () => widget.machines.tunnels.lastLoginRefusal,
      thenConnections: () => thenConnections = true,
      // Every line that runs in a WSL distribution is kept in the operations record, as it ran.
      wslSteps: (onReady) => WslSteps(
        onReady: onReady,
        record: (distribution, line, said) => widget.operations.run(
          title: 'In $distribution: $line',
          machine: distribution,
          output: Stream<String>.fromIterable(<String>[line, if (said.trim().isNotEmpty) said.trimRight()]),
        ),
      ),
    );
    if (machine == null) return;
    await widget.machines.add(machine);
    // What the machine says about itself, read once it answers and is the one shown: a machine that
    // cannot run a task is said so before the first start. Adding it does not move what is being
    // acted on, so it is read when the person goes there. Added either way.
    // A machine the wizard set up was asked by its own last step, and goes on to its connections.
    if (!thenConnections) _checkWhenShown(machine);
    if (!thenConnections || !mounted) return;
    // The wizard's last step: how it connects out, now that its daemon can be asked.
    widget.machines.select(machine);
    await _showConnections();
  }

  /// Starts Porelo where it is not answering, then checks the machine once it answers.
  Future<void> _startThenCheck() async {
    final machine = widget.machines.current;
    if (!await _startTheDaemon()) return;
    await _checkOnceItAnswers(machine);
  }

  /// Checks [machine] the first time it is the one shown and answers, once.
  void _checkWhenShown(Machine machine) {
    final fleet = widget.machines.of(machine);
    var done = false;
    late final VoidCallback look;
    look = () {
      if (done || !mounted) return;
      if (widget.machines.current != machine || fleet.reachability != Reachability.connected) return;
      done = true;
      widget.machines.removeListener(look);
      fleet.removeListener(look);
      // After the frame that shows the machine: going there closes what was open for the one before.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.machines.current == machine) unawaited(_checkTheMachine());
      });
    };
    widget.machines.addListener(look);
    fleet.addListener(look);
    look();
  }

  /// Checks [machine] once it answers, if it is still the one shown. Waits half a minute at most.
  Future<void> _checkOnceItAnswers(Machine machine) async {
    final fleet = widget.machines.of(machine);
    // The start is an operation that connects again when it is done; the check waits for that,
    // and is not run against a daemon that did not come.
    final answering = Completer<void>();
    void check() {
      if (fleet.reachability == Reachability.connected && !answering.isCompleted) answering.complete();
    }

    fleet.addListener(check);
    check();
    try {
      await answering.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return;
    } finally {
      fleet.removeListener(check);
    }
    if (mounted && widget.machines.current == machine) await _checkTheMachine();
  }

  /// Offers to start a daemon on a machine that is not answering, and starts it on a yes; answers
  /// whether it was asked to.
  ///
  /// The one thing a silent machine can still be asked. What runs is named before it runs: this
  /// is the interface reaching further into somebody else's machine than forwarding a socket goes,
  /// and it goes no further than a line somebody read and agreed to.
  Future<bool> _startTheDaemon() async {
    final machine = widget.machines.current;
    if (!machine.canBeStartedHere) return false;
    final where = machine.isThisComputer ? 'this computer' : machine.host;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start Porelo on $where?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                machine.isThisComputer
                    ? 'It is not answering. This starts the daemon here, as you. Nothing else is touched.'
                    : 'It is not answering. This logs in and starts the daemon there, as the user you '
                          'log in as. Nothing else on that machine is touched.',
              ),
              const SizedBox(height: Space.normal),
              SelectableText(
                Tunnels.startCommandFor(machine).join(' '),
                key: const Key('what-would-run'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('start-it'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start it'),
          ),
        ],
      ),
    );
    if (yes != true) return false;
    widget.operations.run(title: 'Start Porelo on $where', machine: machine.name, output: _startingSaid(machine));
    return true;
  }

  /// What the start prints, as an operation: the line, then what came back, then the verdict.
  ///
  /// Erroring the stream is how a failure reaches the session record, and connecting again is the
  /// only thing that can say whether it worked — a line that ran cleanly proves nothing.
  Stream<String> _startingSaid(Machine machine) async* {
    yield Tunnels.startCommandFor(machine).join(' ');
    final started = await widget.machines.startPoreloOn(machine);
    yield started.words;
    if (!started.went) throw FailedSaying(started.words);
    await widget.machines.raiseAgainIfNeeded(machine);
    await widget.machines.of(machine).connect();
    final answering = widget.machines.of(machine).reachability == Reachability.connected;
    yield answering ? 'It answers now.' : 'It still does not answer.';
    if (!answering) throw const FailedSaying('It was started, and still nothing answers.');
  }

  /// Offers to stop the daemon on a machine that answers, says first what that costs, and stops it
  /// on a yes.
  ///
  /// **The cost as this machine gives it**: its tasks run on without their daemon, and what goes is
  /// the watching — every open view of it — and any clearance question raised while nothing is
  /// there to ask it, which runs out unanswered. What runs is named before it runs, as a start's is.
  Future<void> _stopTheDaemon() async {
    final machine = widget.machines.current;
    if (!machine.needsATunnel) return;
    final fleet = widget.machines.of(machine);
    final running = fleet.tasks.where((task) => task.running).length;
    final waiting = fleet.clearance.count;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop Porelo on ${machine.host}?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'What runs there goes on running ($running running now), but nothing here '
                'watches it until Porelo is started again. A clearance question raised meanwhile '
                'goes unanswered and runs out.',
                key: const Key('stopping-costs'),
              ),
              if (waiting > 0) ...<Widget>[
                const SizedBox(height: Space.small),
                Text(
                  waiting == 1
                      ? 'One question is waiting for an answer now, and would go unanswered.'
                      : '$waiting questions are waiting for an answer now, and would go unanswered.',
                  key: const Key('stopping-leaves-questions'),
                ),
              ],
              const SizedBox(height: Space.normal),
              SelectableText(
                Tunnels.stopCommandFor(machine).join(' '),
                key: const Key('what-would-run'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('stop-it'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop it'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    widget.operations.run(
      title: 'Stop Porelo on ${machine.host}',
      machine: machine.name,
      output: _stoppingSaid(machine),
    );
  }

  /// What the stop prints, as an operation: the line, what came back, then the verdict — which is
  /// the machine no longer answering, not the line's exit code.
  Stream<String> _stoppingSaid(Machine machine) async* {
    yield Tunnels.stopCommandFor(machine).join(' ');
    final stopped = await widget.machines.stopPoreloOn(machine);
    yield stopped.words;
    if (!stopped.went) throw FailedSaying(stopped.words);
    await widget.machines.of(machine).connect();
    final answering = widget.machines.of(machine).reachability == Reachability.connected;
    yield answering ? 'It still answers.' : 'It no longer answers. Start it again from its menu.';
    if (answering) throw const FailedSaying('It was stopped, and something still answers.');
  }

  /// Shows what a tile's agent writes on the whole right side, following, as its agent formats it.
  /// Closing it makes it small again: it stays on its tile all along.
  void _enlargeConsole(Tile tile) {
    final task = tile.task;
    if (task == null) return;
    _actOn(tile);
    widget.logs.open(tile.fleet.backend, task.name, TileConsole.log, formatted: true);
    widget.shell.openLog(task.name, TileConsole.log, formatted: true);
  }

  /// Asks which log, then opens it. Reading starts whether or not it stays on screen.
  Future<void> _askWhichLog(Task task) async {
    final log = await askWhichLog(context, task: task.name, logs: _fleet.backend.logsOf(task.name));
    if (log == null) return;
    widget.logs.open(_fleet.backend, task.name, log);
    widget.shell.openLog(task.name, log);
  }

  /// Asks before removing, then removes. The refusal, if there is one, arrives on its own.
  Future<void> _askToRemove(Task task) async {
    final agreed = await confirmRemove(context, task: task.name, running: task.running);
    if (!agreed) return;
    await _fleet.removeEvenIfRunning(task.name);
  }

  /// Takes a piece of work down and starts it again from scratch. **Nothing is started after a
  /// refused removal** — that would lose the reason.
  Future<void> _recreate(Task task) async {
    final agreed = await confirmRecreate(
      context,
      task: task.label.isEmpty ? task.name : task.label,
      helpers: task.helpers,
    );
    if (!agreed) return;
    final clear = await _fleet.clearTheWayToRecreate(task.name);
    if (!clear || !mounted) return;

    final project = _fleet.projects
        .where((each) => each.name == task.project)
        .map((each) => each.project.name)
        .firstOrNull;
    final operation = widget.operations.run(
      title: 'Recreate ${task.name}',
      machine: widget.machines.current.name,
      // The same name and the same agent, mode and prompt: recreating changes the environment.
      output: _fleet.backend.startTask(
        task: task.task,
        project: project,
        agent: task.agent.isEmpty ? null : task.agent,
        mode: task.mode.recognized ? task.mode : null,
        prompt: task.prompt.isEmpty ? null : task.prompt,
        repository: _fleet.projectOf(task)?.repositoryOf(task),
      ),
    );
    widget.shell.openOperation(operation.id);
  }

  /// Finds a command, then goes to where it lives and shows it there.
  Future<void> _openFinder() async {
    final chosen = await showCommandFinder(context, _commands());
    if (chosen == null || !mounted) return;
    // Something with no single place on screen runs at once; everything else is shown where it
    // lives, so the next time it is found there.
    if (chosen.home == Home.none || chosen.home == Home.appBar || chosen.home == Home.openedView) {
      chosen.run();
    } else {
      // Where it lives: a piece of work's tile is under Work, a project's menu on its page, setting
      // one up on Projects, and the rest on the machine's page.
      widget.shell.show(
        chosen.id,
        section: switch (chosen.home) {
          Home.tileMenu => Section.work,
          Home.projectMenu || Home.repositoryRow || Home.startTile || Home.templateTile => Section.project,
          Home.followRepository => Section.projects,
          Home.attentionRow => Section.attention,
          Home.machineRow => Section.machines,
          Home.forgeRow => Section.forges,
          Home.projectRow => Section.projects,
          _ => Section.machine,
        },
      );
    }
  }

  void _openWork() {
    final task = _fleet.selectedTask;
    if (task == null) return;
    widget.shell.openDetail();
    // Asked when the detail opens, for this one task: it runs git inside the container.
    unawaited(widget.held.look(_fleet.backend, task.name));
    unawaited(_handIns.look(_fleet.backend, task.name));
  }

  /// Reports what the project file opens, creating nothing.
  ///
  /// Without [repository] this is the plan every repository of the project gets; with one, that
  /// plan and what the repository adds to it.
  void _checkWorkCanStart({String? repository}) {
    final project = _fleet.selectedProject?.project;
    if (project == null) return;
    final operation = widget.operations.run(
      title: repository == null
          ? 'Show what ${project.name} would open'
          : 'Show what ${project.name} · $repository would open',
      machine: widget.machines.current.name,
      output: _fleet.backend.startTask(project: project.name, dryRun: true, repository: repository),
    );
    widget.shell.openOperation(operation.id);
  }

  @override
  Widget build(BuildContext context) {
    final commands = _commands().where((command) => command.visible).toList();
    final shortcuts = <ShortcutActivator, Intent>{
      for (final command in commands)
        if (command.shortcut != null) command.shortcut!: _RunCommand(command.id),
    };
    final size = WindowSize.fromContext(context);

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RunCommand: CallbackAction<_RunCommand>(
            onInvoke: (intent) {
              for (final command in commands) {
                if (command.id != intent.id) continue;
                if (command.available) command.run();
                return null;
              }
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _frameFocus,
          autofocus: true,
          child: Scaffold(
            key: _scaffold,
            appBar: _appBar(size, commands),
            // Behind the menu button when the window is narrow: the work gets the width.
            drawer: size.showsTreeBeside
                ? null
                : Drawer(
                    width: Sizes.drawer,
                    child: SafeArea(child: _rail(Sizes.drawer)),
                  ),
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  if (widget.newerVersion.arrived) NewerVersionBanner(onRestart: () => SystemNavigator.pop()),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        if (size.showsTreeBeside) ...<Widget>[
                          _rail(size.railShowsLabels ? Sizes.treeWithLabels : Sizes.tree),
                          const VerticalDivider(width: Sizes.divider),
                        ],
                        Expanded(
                          child: switch (widget.shell.section) {
                            Section.work => _workArea(),
                            Section.attention => _needsYou(),
                            Section.machines => _machinesPage(),
                            Section.projects => _projectsPage(),
                            Section.forges => _forgesPage(),
                            Section.forge => _forgePage(),
                            Section.machine || Section.project => ListenableBuilder(
                              listenable: _hostRuns,
                              builder: (context, _) => _machineArea(),
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where you are, and what belongs to no machine: the finder, another machine, options, about.
  PreferredSizeWidget _appBar(WindowSize size, List<Command> commands) {
    final machine = widget.machines.current;
    final project = _fleet.selectedProject;
    final title = switch (widget.shell.section) {
      Section.machine => machine.name,
      Section.project => '${machine.name} › ${project?.label ?? ''}',
      final section => section.label,
    };
    return AppBar(
      // Keyed, so a walk can point at it when a narrow window keeps the rail behind it.
      leading: size.showsTreeBeside
          ? null
          : IconButton(
              key: const Key('open-rail'),
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffold.currentState?.openDrawer(),
            ),
      title: Text(title, key: const Key('app-title'), overflow: TextOverflow.ellipsis),
      actions: <Widget>[
        // With the machines behind the menu button, the stop for all of them stays in reach.
        if (!size.showsTreeBeside)
          IconButton(
            key: const Key('stop-everywhere-bar'),
            tooltip: 'Stop everything on every machine',
            icon: Icon(Icons.pan_tool_outlined, color: Theme.of(context).colorScheme.error),
            onPressed:
                widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected)
                ? _stopEverywhere
                : null,
          ),
        IconButton(tooltip: 'Find a command (Ctrl+K)', icon: const Icon(Icons.search), onPressed: _openFinder),
        IconButton(
          key: const Key('watch-another-machine'),
          tooltip: 'Watch another machine…',
          icon: const Icon(Icons.add_to_queue),
          onPressed: _addAMachine,
        ),
        // The rest of the title bar's Machines group beside watching one, which has its own button above; held back
        // unless the host admin's role is held.
        for (final command in commands)
          if (command.home == Home.appBar && command.group == 'Machines' && command.id != 'machines.add')
            IconButton(
              key: Key(command.id),
              tooltip: command.available ? command.label : '${command.label} - ${command.unavailable}',
              icon: const Icon(Icons.dns_outlined),
              onPressed: command.available ? command.run : null,
            ),
        PopupMenuButton<String>(
          key: const Key('options-menu'),
          tooltip: 'Options',
          icon: const Icon(Icons.tune),
          onSelected: (id) {
            for (final command in commands) {
              if (command.id == id && command.available) command.run();
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            for (final command in commands)
              if (command.home == Home.appBar && command.group == 'Options')
                CheckedPopupMenuItem<String>(
                  value: command.id,
                  checked: command.checked ?? false,
                  child: Text(command.label),
                ),
          ],
        ),
        if (widget.walk case final walk?)
          ListenableBuilder(
            listenable: walk,
            builder: (context, _) => walk.hidden
                ? IconButton(
                    key: const Key('walk-show'),
                    tooltip: 'Show the guided walk${walk.title.isEmpty ? '' : ': ${walk.title}'}',
                    icon: const Icon(Icons.assistant_direction_outlined),
                    onPressed: walk.show,
                  )
                : const SizedBox.shrink(),
          ),
        IconButton(
          key: const Key('about'),
          tooltip: 'About Porelo',
          icon: const Icon(Icons.info_outline),
          onPressed: _showAbout,
        ),
      ],
    );
  }

  /// Closes the drawer the tree is in, when it is in one, before going where it was asked.
  void _leaveDrawer() {
    final scaffold = _scaffold.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  }

  /// The daily work, what needs a person, and setting up apart under them.
  Widget _rail(double width) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      _attention,
      widget.shell,
      _forges,
      widget.machines,
      _hostRuns,
      _workView,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) {
      final rows = machinesPageRows(widget.machines, _hostRuns);
      return ShellRail(
        section: widget.shell.section,
        running: <int>[
          for (final machine in widget.machines.all)
            widget.machines.of(machine).tasks.where((task) => task.running).length,
        ].fold(0, (sum, each) => sum + each),
        work: _workView.shownTiles([for (final machine in widget.machines.all) ..._attention.tilesOn(machine)]).length,
        needing: _attention.openRows.length,
        machines: rows.preparations.length + rows.machines.length,
        // Each project once, as the Projects page lists them (walk 10: Default on two
        // machines counted twice).
        // Default is not among them: it left Projects (walk 10).
        projects: <String>{
          for (final machine in widget.machines.all)
            for (final project in widget.machines.of(machine).projects)
              if (project.name != defaultProject) project.name,
        }.length,
        forges: _forges.entries.length,
        width: width,
        onGo: (section) {
          _leaveDrawer();
          widget.shell.goTo(section);
        },
        onRefresh: () => unawaited(_refreshAll()),
        onStopEverywhere:
            widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected)
            ? _stopEverywhere
            : null,
      );
    },
  );

  /// Every machine watched, as a list: setting up, out of the daily way. A machine's details are its
  /// page; its projects are under Projects and its work under Work.
  Widget _machinesPage() => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      widget.machines,
      _hostRuns,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) => MachinesPage(
      machines: widget.machines,
      hostCommands: _hostCommands,
      hostRuns: _hostRuns,
      onHostProtocol: (run) => unawaited(_openHostRun(run)),
      openTerminal: widget.sessions.openTerminal,
      onAdd: _addAMachine,
      onDetails: (machine) {
        widget.machines.select(machine);
        widget.shell.goTo(Section.machine);
      },
      onForget: (machine) {
        widget.machines.select(machine);
        unawaited(_forget());
      },
    ),
  );

  /// Every project on every machine, and the ways to set one up: setting up, out of the daily way.
  Widget _projectsPage() =>
      _opened() ??
      ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          _attention,
          widget.notifications,
          for (final machine in widget.machines.all) widget.machines.of(machine),
        ]),
        builder: (context, _) => ProjectsPage(
          machines: widget.machines,
          muted: widget.notifications.muted,
          highlight: widget.shell.highlight,
          onShown: widget.shell.shown,
          onProject: (machine, project) {
            widget.machines.select(machine);
            widget.machines.of(machine).selectProject(project);
            widget.shell.goTo(Section.project);
          },
          menuFor: (machine, project) => _projectRowMenu(project, on: machine),
          onFromARepository: _fleet.reachability == Reachability.connected ? _fromARepository : null,
          onFollow: _fleet.reachability == Reachability.connected ? () => unawaited(_followARepository()) : null,
        ),
      );

  /// How the work page was left, kept here so it stays while something takes its place.
  final WorkView _workView = WorkView();

  /// Every piece of work on every machine, or what is open over it.
  Widget _workArea() {
    // A refusal takes the place of the page, as on the machine's: a removal the machine refused,
    // said only in the status line, looked like nothing happening (walk 9).
    final refusal = _fleet.refusal;
    final opened = refusal != null ? RefusalView(refusal: refusal, fleet: _fleet) : _opened() ?? _console();
    final page =
        opened ??
        Focus(
          focusNode: _openedFocus,
          child: WorkPage(
            view: _workView,
            reveal: widget.shell.highlight != null && _fleet.selectedTask != null
                ? '${widget.machines.current.name}/${_fleet.selectedTask!.name}'
                : null,
            machines: widget.machines,
            attention: _attention,
            onNewWork:
                widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected)
                ? () => unawaited(_newWork())
                : null,
            onAddAMachine: _addAMachine,
            onSetUpAProject: _fleet.reachability == Reachability.connected ? _fromARepository : null,
            tile: (tile) => TaskTile(
              tile: tile,
              actions: tile.task == null ? const <Command>[] : _tileActions(tile),
              onEnlargeConsole: _enlargeConsole,
              onDecide: (tile, prompt, {required allow}) =>
                  tile.fleet.clearance.decide(tile.fleet.backend, prompt, allow: allow),
              onPutAway: (tile, prompt) => tile.fleet.clearance.forget(prompt),
              onReview: (tile) {
                _actOn(tile);
                unawaited(_openTheGate(tile.task));
              },
              selected:
                  tile.task != null &&
                  widget.machines.current == tile.machine &&
                  tile.fleet.selectedTask?.name == tile.task!.name,
              // Where the finder went to one of its commands, the selected work's menu shows it.
              highlight:
                  tile.task != null &&
                      widget.machines.current == tile.machine &&
                      tile.fleet.selectedTask?.name == tile.task!.name
                  ? widget.shell.highlight
                  : null,
              onShown: widget.shell.shown,
              onSelect: tile.task == null ? null : () => _actOn(tile),
              onOpen: tile.task == null
                  ? null
                  : () {
                      _actOn(tile);
                      _openWork();
                    },
            ),
          ),
        );
    // What an action from a tile said, of the machine it acted on: the work page has tiles of every
    // machine, and an answer nobody saw was an action that seemed to do nothing.
    final machine = widget.machines.current;
    return Column(
      children: <Widget>[
        Expanded(child: page),
        StatusLine(
          fleet: _fleet,
          operations: widget.operations,
          machine: machine.name,
          cannotNotify: widget.notifications.problem,
          highlighted: false,
          onShowOperations: widget.shell.openOperations,
        ),
      ],
    );
  }

  /// Starts new work: where first, when there is more than one machine that answers.
  Future<void> _newWork() async {
    final answering = <Machine>[
      for (final machine in widget.machines.all)
        if (widget.machines.of(machine).reachability == Reachability.connected) machine,
    ];
    if (answering.isEmpty) return;
    var where = answering.length == 1 ? answering.single : null;
    where ??= await showDialog<Machine>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('new-work-where'),
        title: const Text('Where should it run?'),
        children: <Widget>[
          for (final machine in answering)
            SimpleDialogOption(
              key: ValueKey<String>('new-work-on ${machine.name}'),
              onPressed: () => Navigator.of(context).pop(machine),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.tight),
                child: Text(machine.name),
              ),
            ),
        ],
      ),
    );
    if (where == null || !mounted) return;
    widget.machines.select(where);
    final fleet = widget.machines.of(where);
    final projects = <ProjectOnScreen>[
      for (final project in fleet.projects)
        if (project.name != defaultProject && project.canBeActedOn) project,
    ];
    // Then in which project, or in none: work without a project is default, every machine's.
    final chosen = projects.isEmpty
        ? defaultProject
        : await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              key: const Key('new-work-project'),
              title: Text('In which project, on ${where!.name}?'),
              children: <Widget>[
                for (final project in projects)
                  SimpleDialogOption(
                    key: ValueKey<String>('new-work-in ${project.name}'),
                    onPressed: () => Navigator.of(context).pop(project.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.tight),
                      child: Text(project.label),
                    ),
                  ),
                SimpleDialogOption(
                  key: const ValueKey<String>('new-work-in $defaultProject'),
                  onPressed: () => Navigator.of(context).pop(defaultProject),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: Space.tight),
                    child: Text('Default: work without a project of its own'),
                  ),
                ),
              ],
            ),
          );
    if (chosen == null || !mounted) return;
    // Without a project is default, which a machine need not list among its projects.
    if (chosen == defaultProject) return _startInDefault();
    fleet.selectProject(chosen);
    await _startWork();
  }

  /// What needs a person. A tile leads to where its work lives.
  Widget _needsYou() {
    final opened = _opened() ?? _console();
    if (opened != null) return opened;
    return Focus(
      focusNode: _openedFocus,
      child: AttentionView(
        attention: _attention,
        onOpenHost: (project) {
          final run = _hostRuns.of(project);
          if (run != null) unawaited(_openHostRun(run));
        },
        unlockFor: _unlockFor,
        onStopFollowing: (machine, project) =>
            unawaited(_previewProjectRemoval(widget.machines.of(machine), project.name)),
        onDecide: (tile, prompt, {required allow}) =>
            tile.fleet.clearance.decide(tile.fleet.backend, prompt, allow: allow),
        onPutAway: (tile, prompt) => tile.fleet.clearance.forget(prompt),
        onOpenOperation: (operation) => widget.shell.openOperation(operation.id),
        actionsFor: _tileActions,
        onSelect: _goToWork,
        onReview: (tile) {
          _actOn(tile);
          unawaited(_openTheGate(tile.task));
        },
      ),
    );
  }

  /// Where somebody is now, as a place a session can belong to.
  ConsolePlace get _here => switch (widget.shell.section) {
    Section.attention => const ConsolePlace(section: Section.attention),
    Section.work => const ConsolePlace(section: Section.work),
    Section.project => ConsolePlace(
      section: Section.project,
      machine: widget.machines.current.name,
      project: _fleet.selectedProject?.name,
    ),
    _ => ConsolePlace(section: Section.machine, machine: widget.machines.current.name),
  };

  /// Whether the open session belongs to where somebody is.
  bool get _consoleIsHere => widget.sessions.current != null && widget.sessions.place == _here;

  /// The open session, when somebody is where it was opened; nothing anywhere else.
  Widget? _console() {
    final session = widget.sessions.current;
    if (session == null || !_consoleIsHere) return null;
    final leave = leaveWorkCommand(() => unawaited(widget.sessions.leave()));
    return SessionView(session: session, focusNode: _openedFocus, onLeave: leave.run);
  }

  /// One machine: its title and menu, then its projects and work, then what it ran.
  Widget _machineArea() {
    final machine = widget.machines.current;
    final fleet = _fleet;
    // A project's page whose project went - deleted, cleared, no longer followed - goes back to the
    // list of projects rather than standing empty (walk 9).
    if (widget.shell.section == Section.project && fleet.selectedProject == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.shell.section == Section.project && _fleet.selectedProject == null) {
          widget.shell.goTo(Section.projects);
        }
      });
    }
    final highlight = widget.shell.highlight;
    // A refusal takes the place of whatever was open: it is the most important thing on the
    // screen until somebody has decided about it.
    final refusal = fleet.refusal;
    final opened = refusal != null ? RefusalView(refusal: refusal, fleet: fleet) : _opened() ?? _console();
    _keepTheVaultButtonTrue(machine, fleet);
    return Column(
      children: <Widget>[
        // A project's page is the project's alone: its machine is in the title bar, never a bar of its
        // own above it (walk 9).
        if (widget.shell.section != Section.project)
          MachineTitle(
            machine: machine,
            fleet: fleet,
            tunnel: widget.machines.tunnels.of(machine),
            kind: machineKind(widget.machines, machine),
            onStop: _stopEverything,
            vault: VaultButtons(
              vault: widget.vault,
              onLock: fleet.reachability == Reachability.connected
                  ? () => unawaited(_actOnTheVault(widget.vault.lockDoes))
                  : null,
              onOpenWithThePassphrase: fleet.reachability == Reachability.connected && _canUnlockHere
                  ? () => unawaited(_unlockHere())
                  : null,
              onMakeIt: fleet.reachability == Reachability.connected && _canMakeHere
                  ? () => unawaited(_makeTheVault())
                  : null,
            ),
            menu: _machineMenu(),
            highlight: highlight,
            onShown: widget.shell.shown,
          ),
        Expanded(child: opened ?? _machineBody(machine, fleet, highlight)),
        StatusLine(
          fleet: fleet,
          operations: widget.operations,
          machine: machine.name,
          cannotNotify: widget.notifications.problem,
          highlighted: highlight == 'operations.show',
          onShowOperations: widget.shell.openOperations,
        ),
      ],
    );
  }

  /// Running work on every project, or the selected project with its work under its header.
  Widget _machineBody(Machine machine, FleetModel fleet, String? highlight) {
    final projects = fleet.projects;
    // A project's page shows its project; a machine's page the machine alone, whatever project is
    // chosen on it, so the choice is kept for when Projects opens one again.
    final narrowed = widget.shell.section == Section.project ? fleet.selectedProject : null;
    final jobs = narrowed == null ? const <Template>[] : widget.templates.forProject(narrowed.name);
    final hostCommandsHere = narrowed == null ? _hostCommands(machine) : const <Command>[];
    // Built once for the page: its menu and its tiles share the command objects.
    final projectCommandsHere = narrowed == null
        ? null
        : <Command>[
            ..._commands().where((command) => command.id == 'work.start' || command.id == 'project.follow'),
            ..._projectMenu(narrowed),
          ];
    final itsWork = CommandTile(
      key: const Key('its-work'),
      command: projectWorkCommand(
        open: () {
          _workView
            ..machine = machine.name
            ..project = narrowed == null ? null : (narrowed.name == defaultProject ? '' : narrowed.name);
          widget.shell.goTo(Section.work);
        },
      ),
      icon: Icons.play_circle_outline,
      description: narrowed == null
          ? 'Show the work belonging to this machine.'
          : 'Show the work belonging to this project.',
    );
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            key: const Key('machine-area'),
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (narrowed == null)
                  Wrap(
                    spacing: Space.normal,
                    runSpacing: Space.normal,
                    children: <Widget>[
                      for (final command in hostCommandsHere)
                        CommandTile(
                          command: command,
                          icon: switch (command.id) {
                            'host.protocol' => Icons.receipt_long_outlined,
                            'machine.takeDown' => Icons.delete_outline,
                            _ => Icons.tune_outlined,
                          },
                          description: switch (command.id) {
                            'host.protocol' => 'Read the protocol from setting up this server.',
                            'machine.takeDown' =>
                              'End the project tasks and room, copy its files back and give the server back.',
                            _ => command.label,
                          },
                          danger: command.id == 'machine.takeDown',
                        ),
                      itsWork,
                    ],
                  ),
                // Scrolls with the work: a project with many repositories is taller than any window,
                // and a fixed header that grows pushes the work out of sight. The title bar still
                // names the project.
                if (narrowed != null)
                  ProjectHeader(
                    project: narrowed,
                    muted: widget.notifications.muted.contains(narrowed.name),
                    menu: projectCommandsHere!,
                    highlight: highlight == 'work.start' ? null : highlight,
                    onShown: widget.shell.shown,
                    onSync: (repository) => unawaited(_syncTheUpstream(repository: repository)),
                    onCheck: narrowed.project.following == null ? null : () => unawaited(_checkNow(narrowed)),
                    checking: _check.isChecking(narrowed.name),
                    checked: _check.saidAbout(narrowed.name),
                    onBackups: (repository) => unawaited(_showTheBackups(repository: repository)),
                    onOpens: (repository) => _checkWorkCanStart(repository: repository),
                    onReach: (repository) => unawaited(_openEgress(repository: repository)),
                    onStart: (repository) => unawaited(_startWork(repository: repository)),
                    homeserver: _homeserverWords(machine, narrowed.name),
                    startUnavailable: StartWork.whyNot(narrowed.project) ?? notAnswering(fleet),
                  ),
                // A project is one, wherever it lies: where it is on several machines, which one this
                // page shows is chosen here (walk 9).
                if (narrowed != null)
                  Builder(
                    builder: (context) {
                      final on = <Machine>[
                        for (final each in widget.machines.all)
                          if (widget.machines.of(each).projects.any((project) => project.name == narrowed.name)) each,
                      ];
                      if (on.length < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: Space.small),
                        child: Wrap(
                          spacing: Space.small,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text('On', style: Theme.of(context).textTheme.labelMedium),
                            for (final each in on)
                              ChoiceChip(
                                key: ValueKey<String>('project-on ${each.name}'),
                                label: Text(each.name),
                                selected: each == machine,
                                onSelected: (_) {
                                  widget.machines.select(each);
                                  widget.machines.of(each).selectProject(narrowed.name);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                // A fresh machine's first step, said where a person looks rather than only marked
                // in the header: nothing an agent signs in with can be kept until it is there.
                if (narrowed == null)
                  ListenableBuilder(
                    listenable: widget.vault,
                    builder: (context, _) => widget.vault.missing && fleet.reachability == Reachability.connected
                        ? _NextStep(
                            key: const Key('next-step-vault'),
                            title: 'Next: make the vault on ${machine.name}',
                            says:
                                'It keeps what your agent signs in with and the keys ${machine.name} '
                                'pushes with, behind a passphrase only you know. Nothing can be kept there '
                                'until it is made.',
                            act: _canMakeHere ? 'Make it, in a terminal' : null,
                            onAct: () => unawaited(_makeTheVault()),
                            otherwise: machine.kind == 'host'
                                ? "${machine.name}'s vault is made by its setup, from your secrets file: complete "
                                      'its setup where Needs you asks for it.'
                                : "Run 'porelo setup' in a terminal on ${machine.name}, which makes it.",
                          )
                        : const SizedBox.shrink(),
                  ),
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.small),
                    child: Text(_noProjects(fleet), key: const Key('no-projects')),
                  ),
                const SizedBox(height: Space.small),
                if (narrowed != null)
                  ProjectCommandTiles(commands: projectCommandsHere!, itsWork: itsWork, highlight: highlight),
                Wrap(
                  spacing: Space.normal,
                  runSpacing: Space.normal,
                  children: <Widget>[
                    for (final job in jobs)
                      TemplateTile(
                        job: job,
                        highlighted: highlight == 'template.start/${job.project}/${job.name}',
                        unavailable: job.startable
                            ? notAnswering(fleet)
                            : 'this job is missing something it needs to run',
                        onPressed: () => unawaited(_startFromTemplate(job)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _homeserversChanged() {
    if (mounted) setState(() {});
  }

  /// Where a Matrix client here reaches [project]'s homeserver on [machine], or why it cannot; null
  /// where nobody joined its conversation from here.
  String? _homeserverWords(Machine machine, String project) {
    final port = _homeservers.portOf(machine, project);
    if (port != null) return 'A Matrix client here reaches its homeserver at http://127.0.0.1:$port.';
    final problem = _homeservers.problemOf(machine, project);
    return problem == null ? null : 'Its homeserver is not reachable from here: $problem';
  }

  static String _noProjects(FleetModel fleet) => switch (fleet.reachability) {
    Reachability.connecting => 'Asking the backend what is here.',
    Reachability.unreachable => 'Not connected, so what is here is unknown. This is not an empty machine.',
    Reachability.incompatible => 'This backend speaks nothing this build understands.',
    Reachability.connected => 'No work has run on this machine, so no project names itself yet.',
  };

  /// What is open over the frame, or null when nothing is.
  ///
  /// Resolved rather than read straight off the model, because what a view points at can go away
  /// underneath it: work that stopped existing, an operation this session never had.
  Widget? _opened() {
    switch (widget.shell.opened) {
      case NothingOpened():
        return null;
      case WorkOpened():
        final task = _fleet.selectedTask;
        if (task == null) return null;
        return WorkDetail(
          task: task,
          repository: _fleet.projectOf(task)?.repositoryOf(task),
          held: widget.held,
          handing: _handing,
          handIns: _handIns,
          onClose: widget.shell.close,
        );
      case ConnectionsOpened():
        return ConnectionsView(
          connections: widget.connections,
          onAdd: () => unawaited(_addAConnection()),
          onForget: (match) => unawaited(widget.connections.forget(_fleet.backend, match)),
          onClose: widget.shell.close,
          onStoreInATerminal: _storesHere ? () => unawaited(_storeInATerminal()) : null,
          onSendAKey: _storesHere ? _sendAKey : null,
          keysAt: widget.machines.setup.sshDirectory,
          pick: widget.pickAFile,
        );
      case VaultOpened():
        return VaultView(
          vault: widget.vault,
          onRevoke: (slot) => widget.vault.devices.revoke(_fleet.backend, slot),
          onClose: widget.shell.close,
          onUnlockHere: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
          onMakeHere: _canMakeHere ? () => unawaited(_makeTheVault()) : null,
          onGrant: (credential) => unawaited(_grant(credential)),
        );
      case BackupsOpened():
        return BackupsView(
          backups: widget.backups,
          onConsider: (backup) => widget.backups.consider(_fleet.backend, backup),
          onConsiderRestoring: (backup) => widget.backups.considerRestoring(_fleet.backend, backup),
          onRestore: ({required force}) => _restoreTheMirror(force: force),
          onRemove: _removeTheBackup,
          onLetItBe: widget.backups.letItBe,
          onClose: widget.shell.close,
        );
      case ProvidersOpened():
        return AuthenticationView(
          authentication: widget.authentication,
          onImport: _import,
          onClose: widget.shell.close,
        );
      case ReadinessOpened():
        return HostReadinessView(
          readiness: widget.readiness,
          machine: widget.machines.current.name,
          onCheckAgain: () => widget.readiness.look(_fleet.backend),
          onClose: widget.shell.close,
        );
      case AgentsOpened():
        return AgentsView(inventory: widget.inventory, onClose: widget.shell.close);
      case EgressOpened():
        return EgressView(egress: widget.egress, onClose: widget.shell.close);
      case GateOpened():
        return GateView(gate: widget.gate, focusNode: _openedFocus, onOpen: _look, onClose: widget.shell.close);
      case ReviewOpened():
        return ReviewView(
          gate: widget.gate,
          onBack: widget.shell.openGate,
          onClose: widget.shell.close,
          onApprove: _approve,
          onReject: _reject,
          login: widget.machines.current.needsATunnel ? widget.machines.current.host : null,
        );
      case LogOpened(:final task, :final log, :final formatted):
        final tail = widget.logs.find(task, log, formatted: formatted);
        if (tail == null) return null;
        return LogView(tail: tail, logs: widget.logs, onClose: widget.shell.close);
      case ProjectFollowingOpened():
        return ProjectFollowingPanel(
          following: widget.following,
          onFollow: ({bool acceptRewrite = false}) async {
            await widget.following.follow(acceptRewrite: acceptRewrite);
            final said = widget.following.answer?.words;
            if (said != null) _fleet.say('${widget.following.name.trim()}: $said');
          },
          onDone: (taken) => unawaited(_doneFollowing(taken)),
          onUnlockHere: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
          onSetUpItsConnection: () => unawaited(_setUpTheConnectionOfTheFollow()),
          onShowItsConnection: () => unawaited(_showConnections()),
          onStoreInATerminal: _storesHere ? () => unawaited(_storeWhatTheCheckNamed()) : null,
          onFromARepository: () {
            widget.shell.close();
            widget.following.letItBe();
            _fromARepository();
          },
        );
      case OperationsOpened():
        return OperationsList(
          operations: widget.operations,
          machine: widget.machines.current.name,
          focusNode: _openedFocus,
          onOpen: widget.shell.openOperation,
          onClose: widget.shell.close,
        );
      case OperationOpened(:final id):
        final operation = widget.operations.byId(id);
        if (operation == null) return null;
        // Open is seen, wherever it was opened from and whether it failed before or while it was.
        // Not now: this runs while the frame is drawn, and seeing it redraws the frame.
        if (operation.failed && !operation.seen) {
          scheduleMicrotask(() => widget.operations.see(operation));
        }
        return OperationOutputView(
          key: ValueKey(operation.id),
          operation: operation,
          run: _runs[id],
          restart: _runs[id] == null ? null : _restartCommand(_runs[id]!),
          onBack: widget.shell.openOperations,
          onClose: widget.shell.close,
        );
    }
  }

  /// Opens a shell inside running work, or goes back to the one that is already open.
  /// Opens a session on [task] where somebody is, leaving the one that was open: **one at a time**.
  void _openSession(Task task) {
    final machine = widget.machines.current;
    final before = widget.sessions.current;
    widget.sessions.openOn(task.name, machine, at: _here, startedAt: task.running ? task.startedAt : null);
    if (before != null && (before.task != task.name || before.machine != machine)) {
      _fleet.say('Left the session in ${before.task}; the work there carries on.');
    }
    widget.shell.close();
  }

  @override
  void dispose() {
    for (final run in _runs.values) {
      run.dispose();
    }
    widget.shell.removeListener(_moveKeyboard);
    widget.sessions.removeListener(_moveKeyboard);
    widget.settings.removeListener(_keepRefreshing);
    _refreshing?.cancel();
    _leaving.dispose();
    _homeservers.removeListener(_homeserversChanged);
    _check.removeListener(_homeserversChanged);
    _check.dispose();
    _attention.dispose();
    _workView.dispose();
    _hostRuns.dispose();
    _homeservers.dispose();
    _openedFocus.dispose();
    _frameFocus.dispose();
    _handing.dispose();
    _handIns.dispose();
    _startingAgents.dispose();
    // Only the one made here: a connection the app handed in is the app's.
    if (widget.forges == null) _forges.dispose();
    super.dispose();
  }
}

/// Runs the command with this id, whatever key, menu or finder asked for it.
class _RunCommand extends Intent {
  const _RunCommand(this.id);

  final String id;
}

/// The user new machines run work as, checked as it is typed.
class _WorkUserDialog extends StatefulWidget {
  const _WorkUserDialog({required this.current});

  final String current;

  @override
  State<_WorkUserDialog> createState() => _WorkUserDialogState();
}

class _WorkUserDialogState extends State<_WorkUserDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = Settings.isUserName(_name.text.trim());
    return AlertDialog(
      title: const Text('New machines run work as'),
      content: SizedBox(
        width: Sizes.dialogNarrow,
        child: TextField(
          key: const Key('work-user'),
          controller: _name,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'User',
            helperText:
                "Created on a new machine by Porelo's setup script. Machines already set up "
                'keep theirs.',
            errorText: valid ? null : 'Lower-case letters, digits, _ and -, starting with a letter',
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('work-user-save'),
          onPressed: valid ? () => Navigator.of(context).pop(_name.text.trim()) : null,
          child: const Text('Keep it'),
        ),
      ],
    );
  }
}

/// The forges set up on this computer, kept in its settings beside everything else it remembers.
class _ForgesInSettings implements ForgeEntries {
  _ForgesInSettings(this._settings);

  final Settings _settings;

  @override
  Future<List<Object?>> read() async => _settings.forges;

  @override
  Future<void> write(List<Map<String, Object?>> entries) => _settings.rememberForges(entries);
}

/// The one step a machine needs next, said in the work's own area: what it is, why, and the button
/// that does it, or what to do instead where nothing here can.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.title,
    required this.says,
    required this.act,
    required this.onAct,
    required this.otherwise,
    super.key,
  });

  final String title;
  final String says;
  final String? act;
  final VoidCallback onAct;
  final String otherwise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.normal),
      padding: const EdgeInsets.all(Space.normal),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(Radii.small)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.tight),
          Text(says),
          const SizedBox(height: Space.small),
          if (act case final act?)
            FilledButton(key: const Key('next-step-act'), onPressed: onAct, child: Text(act))
          else
            Text(otherwise, key: const Key('next-step-otherwise')),
        ],
      ),
    );
  }
}
