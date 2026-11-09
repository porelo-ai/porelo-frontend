import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guided_walk/guided_walk.dart';

import '../app/desk.dart';
import '../app/identity.dart';
import '../app/environment_tokens.dart';
import '../app/homeserver_forwards.dart';
import '../app/host_check_run.dart';
import '../app/host_access.dart';
import '../app/host_progress.dart' show HostProgress, HostRepositoryProgress;
import '../app/host_runs.dart';
import '../app/product.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/forge_key_check.dart';
import '../app/machine_binding.dart';
import '../app/machine_tools.dart';
import '../app/machine_clearing.dart';
import '../app/login_forward.dart';
import '../app/granting.dart';
import '../app/attention.dart';
import '../app/commands.dart';
import '../app/fleet_backend.dart';
import '../app/fleet_model.dart';
import '../app/host_token.dart';
import '../app/run_here.dart';
import '../app/task_certifying.dart';
import '../app/organization_source.dart';
import '../app/porelo_organization_source.dart';
import '../app/egress.dart';
import '../app/agent_inventory.dart';
import '../app/authentication.dart';
import '../app/backups.dart';
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
import '../app/conversation.dart';
import '../app/vault_unlock.dart';
import '../app/project_deletion.dart';
import '../app/hand_in.dart';
import '../app/session.dart';
import '../app/unattended_run.dart';
import '../app/key_recovery.dart';
import 'key_recovery_dialog.dart';
import 'organization_token_words.dart';
import 'organization_access_dialogs.dart';
import 'clearing_view.dart';
import '../app/settings.dart';
import '../app/shell_model.dart';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart'
    show
        CentralToken,
        HostCardSsh,
        HostFilesRefused,
        OpenSsh,
        ProjectTransfer,
        organizationRefreshArguments,
        organizationRefreshFeedCommand,
        RemoteNotStarted,
        SecretsFile,
        projectTransferFeedCommand;

import '../app/project_transfers.dart';
import '../app/host_keys.dart' show SshHostKeys;
import '../app/host_token_sources.dart';
import '../app/server_first_login.dart' show tryRootLogin;
import '../app/server_setup.dart';
import 'server_setup_wizard.dart';

import 'attention_view.dart';
import 'command_finder.dart';
import 'command_menu.dart';
import 'clearance_mode_view.dart';
import 'egress_view.dart';
import 'agents_view.dart';
import 'authentication_view.dart';
import 'backups_view.dart';
import 'emergency_stop_view.dart';
import 'connection_wizard.dart';
import 'connections_view.dart';
import 'pick_a_file.dart';
import 'unlock_terminal.dart';
import 'project_deletion_view.dart';
import 'projects_page.dart';
import 'machine_details_page.dart';
import 'project_details_page.dart';
import '../app/project_standing.dart';
import 'shell_rail.dart';
import 'facts_page.dart';
import 'filtered_list_section.dart';
import 'vault_actions.dart';
import 'vault_view.dart';
import 'start_agents_view.dart';
import 'first_start_view.dart' show askFirstStart;
import 'start_work_view.dart';
import 'sign_in_panel.dart';
import '../app/agent_sign_in.dart';
import 'widening_view.dart';
import 'gate_view.dart';
import 'words_dialog.dart';
import 'host_readiness_view.dart';
import 'how_long.dart';
import 'leaving.dart';
import 'log_view.dart';
import 'machine_switcher.dart';
import 'machine_tree.dart';
import 'machine_view.dart';
import 'managing_page.dart';
import 'expandable_list_row.dart' show StateChip;
import 'machines_page.dart';
import 'narrowing_view.dart';
import 'operations.dart';
import 'panes.dart';
import 'destinations_view.dart';
import 'identity_view.dart';
import 'grant_view.dart';
import 'messages_view.dart';
import 'repositories_view.dart';
import 'project_forge_view.dart';
import 'organization_host_pages.dart';
import 'organization_page.dart';
import 'page_explanation.dart';
import 'organization_dialogs.dart';
import 'organization_project_pages.dart';
import 'default_view.dart';
import 'forges_page.dart';
import 'peers_view.dart';
import 'prepare_view.dart';
import 'refusal.dart';
import 'status_line.dart';
import 'running_view.dart';
import 'tokens.dart';
import 'window_size.dart';
import 'work_page.dart';
import 'wsl_machine.dart';
import 'dialog_scroll.dart';
import 'host_dialog.dart';
import 'image_settings_view.dart';

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
    required this.connections,
    this.forges,
    this.settingsDropped = false,
    this.organizationSource,
    this.hostConnections,
    this.connectionsFor,
    this.forgeKeyCheck,
    this.hostAccess,
    this.identity,
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

  /// Whether this start dropped settings from before the organization model, which the person is told once.
  final bool settingsDropped;

  /// Where the organization is read and changed, absent while this computer reads none.
  final OrganizationSource? organizationSource;

  /// This person's connection to each host of the organization, absent while this computer reads none.
  final HostConnections? hostConnections;

  /// Makes the connections from the organization read here, where [hostConnections] gives none.
  final HostConnections Function(Organization organization)? connectionsFor;

  /// Whether the person's key is listed on their central forge account, absent until supplied.
  final ForgeKeyCheck? forgeKeyCheck;

  /// Who may prepare a host and what goes to the organization, given to host setup and its dialogs.
  final HostAccess? hostAccess;

  /// The local card, absent where nothing reads it.
  final IdentityModel? identity;

  /// The project-scoped Core and host adapters, supplied once their contracts are served.

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

  final _machineTools = <Machine, MachineTools>{};

  MachineTools _toolsFor(Machine machine) => _machineTools.putIfAbsent(machine, () {
    final tools = MachineTools(widget.vault.devices.store);
    for (final model in [
      tools.vault,
      tools.vault.devices,
      tools.connections,
      tools.inventory,
      tools.authentication,
      tools.readiness,
    ]) {
      model.addListener(_homeserversChanged);
    }
    return tools;
  });
  bool _stillWatching(Machine machine, MachineTools tools) =>
      mounted && widget.machines.all.contains(machine) && identical(_machineTools[machine], tools);

  void _releaseTools(MachineTools tools) {
    for (final model in [
      tools.vault,
      tools.vault.devices,
      tools.connections,
      tools.inventory,
      tools.authentication,
      tools.readiness,
    ]) {
      model.removeListener(_homeserversChanged);
    }
    tools.dispose();
  }

  void _dropForgottenTools() {
    final watched = widget.machines.all.toSet();
    for (final machine in _machineTools.keys.toList()) {
      if (watched.contains(machine)) continue;
      _releaseTools(_machineTools.remove(machine)!);
      _providerCards.remove(machine);
      _destinationCards.remove(machine);
      _sectionRetries.remove(machine);
      _vaultAskedFor.remove(machine);
      for (final section in MachineSection.values) {
        final key = ShellPlace(Section.machine, machine: machine, machineSection: section).key;
        _sectionReadAt.remove(key);
        if (_treeTool == key) _treeTool = null;
      }
    }
  }

  Machine get _toolMachine {
    final place = widget.shell.place;
    return place.section == Section.machine && place.machine != null && widget.machines.all.contains(place.machine)
        ? place.machine!
        : widget.machines.current;
  }

  Vault get _vault => _toolsFor(_toolMachine).vault;

  final _openedFocus = FocusNode(debugLabel: 'opened');
  final _scaffold = GlobalKey<ScaffoldState>();

  /// Starting the agent each repository of a project names, at one click.
  final _startingAgents = StartAgents();
  // The frame's own focus, so the keyboard works the moment the window opens and after anything
  // open over it closes.
  final _frameFocus = FocusNode(debugLabel: 'frame');
  late final Attention _attention;
  late final HostRuns _hostRuns;

  /// The central transfers' guards; each transfer itself runs in a terminal the person types the master password into.
  final _transfers = ProjectTransfers(source: _TerminalOnly());

  /// The card host projects whose push or pull runs now, `<machine>/<project>`: one at a time each.
  final _transfersRunning = <String>{};

  /// A file being handed to work, and the last one's outcome.
  final _handing = HandingIn();

  /// What the open work's name has been handed, asked when it opens.
  final _handIns = HandInRecord();

  /// The homeservers joined from here, forwarded while the window runs.
  late final HomeserverForwards _homeservers;
  late final AppLifecycleListener _leaving;
  final _runs = <String, UnattendedRun>{};

  /// The sign-in offered on a start that failed while its agent read not signed in, by operation: **never a second
  /// start**, only the sign-in.
  final _signInsAfterAFailedStart = <String, SigningIn>{};

  /// What waits on the end of a start to offer its sign-in, by operation: taken off when the window goes.
  final _waitsForAFailedStart = <String, VoidCallback>{};

  /// This build's version, stamped by the package build; a build from source says so.
  static const _version = String.fromEnvironment('PORELO_VERSION', defaultValue: 'built from source');

  @override
  void initState() {
    super.initState();
    final initialTools = MachineTools.existing(
      vault: widget.vault,
      connections: widget.connections,
      inventory: widget.inventory,
      authentication: widget.authentication,
      readiness: widget.readiness,
    );
    // A recreated frame can receive observations already owned by a different machine.
    final vaultOwner = widget.vault.about;
    final connectionOwner = widget.connections.machine;
    final suppliedOwner = vaultOwner.isNotEmpty ? vaultOwner : connectionOwner;
    final unread =
        widget.vault.state == null &&
        !widget.vault.busy &&
        widget.vault.problem == null &&
        widget.connections.all.isEmpty &&
        !widget.connections.busy &&
        widget.connections.problem == null &&
        !widget.inventory.asked &&
        !widget.inventory.busy &&
        widget.inventory.problem == null &&
        widget.authentication.answer == null &&
        !widget.authentication.busy &&
        widget.authentication.problem == null &&
        widget.readiness.health == null &&
        !widget.readiness.busy &&
        widget.readiness.problem == null;
    final owner = suppliedOwner.isEmpty
        ? (unread ? widget.machines.current : null)
        : widget.machines.all.where((machine) => machine.name == suppliedOwner).firstOrNull;
    if (owner != null && (vaultOwner.isEmpty || connectionOwner.isEmpty || vaultOwner == connectionOwner)) {
      _machineTools[owner] = initialTools;
    }
    widget.machines.resumeAutomaticRetries();
    widget.shell.initializeNavigation(widget.machines.current);
    widget.shell.addListener(_followTreeTool);
    widget.shell.addListener(_checkOrganizationPlace);
    _organization?.addListener(_checkOrganizationPlace);
    _observedMachine = widget.machines.current;
    widget.machines.addListener(_machineChanged);
    final source = widget.organizationSource;
    if (source is PoreloOrganizationSource) {
      source.prepareForgeWrite = (repository) =>
          prepareOrganizationForge(context, repository, _forges, open: widget.sessions.openTerminal);
      source.confirmForgeHost = _forgeTrust.ask;
    }
    if (widget.settingsDropped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('settings-dropped'),
            content: Text(settingsDroppedWords),
            duration: Duration(minutes: 1),
            showCloseIcon: true,
          ),
        );
      });
    }
    _standings.addListener(_homeserversChanged);
    unawaited(_standings.read());
    _organization?.addListener(_readStandings);
    _hostRuns = HostRuns(
      widget.machines,
      hostAccess: widget.hostAccess,
      onReady: _hostReady,
      say: (words) => _fleet.say(words),
    );
    // A read of the organization or the proven identity changes what a host admin is offered at once.
    widget.hostAccess?.addListener(_homeserversChanged);
    _attention = Attention(widget.machines, widget.settings, widget.operations)..hostRuns = _hostRuns;
    _homeservers = HomeserverForwards(widget.settings);
    // One that cannot be raised is said under Needs you; the project's page says the address.
    _attention.homeservers = _homeservers;
    if (_organization case final organization?) {
      _attention.watchOrganization(organization, _hostConnections);
      // *Needs you* may be the first place looked at, and says nothing of an organization not read.
      unawaited(organization.refresh());
    }
    // A person is never asked for the same token twice: what created the organization is the forge's access.
    _organization?.afterWrite = (change, input) {
      if (change == OrganizationChange.createOrganization && input['address'] != null) {
        unawaited(_forges.enterForgeOf(input['address']!));
      }
    };
    _homeservers.addListener(_homeserversChanged);
    _organization?.addListener(_homeserversChanged);
    // What was joined before is reachable again from the start, at the same port.
    unawaited(_homeservers.restore(widget.machines));
    // Which forges are set up is read now, asking none of them anything, so a project's menu can say
    // whether its repository's forge is one of them.
    unawaited(_forges.readList());
    // Closing the window is how the interface ends, so the forwards it raised end with it.
    _leaving = AppLifecycleListener(onExitRequested: _letGo);
    widget.shell.addListener(_moveKeyboard);
    widget.sessions.addListener(_moveKeyboard);
    widget.shell.addListener(_leaveTheSessionWithItsPage);
    widget.shell.addListener(_leaveTheSignInsWithTheirView);
    _workView.addListener(_leaveTheSessionWithItsPage);
    _workView.addListener(_moveKeyboard);
    widget.settings.addListener(_keepRefreshing);
    _keepRefreshing();
    _followTreeTool();
  }

  /// How this person stands in each project, which decides whether they may move its work.
  String? _treeTool;
  Machine? _observedMachine;
  void _machineChanged() {
    _dropForgottenTools();
    _leaveTheSignInsOfForgottenMachines();
    final machine = widget.machines.current;
    if (_observedMachine == machine) return;
    _observedMachine = machine;
    _toolsFor(machine).connections.prepareFor(machine.name);
  }

  void _checkOrganizationPlace() {
    final organization = _organization;
    if (organization == null || organization.view != null || organization.noOrganization) {
      final name = organization?.view?.name;
      if (_organizationProjectFrom?.section == Section.organization && _organizationProjectFrom?.organization != name) {
        _organizationProjectFrom = null;
      }
      if (_organizationHostFrom?.section == Section.organization && _organizationHostFrom?.organization != name) {
        _organizationHostFrom = null;
      }
      widget.shell.checkOrganization(name);
    }
  }

  void _followTreeTool() {
    final place = widget.shell.place;
    if (place.section != Section.projects) {
      _organizationProject = null;
      _organizationProjectFrom = null;
    }
    if (place.section != Section.machines && place.section != Section.machine) {
      _organizationHost = null;
      _organizationHostFrom = null;
    }
    if (_treeTool == place.key) return;
    _treeTool = place.key;
    final section = place.machineSection;
    final machine = place.machine;
    if (section == null || machine == null || !widget.machines.all.contains(machine)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.shell.place.key == place.key) {
        unawaited(_readMachineSection(machine, section));
      }
    });
  }

  Future<void> _readMachineSection(Machine machine, MachineSection section) async {
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    await fleet.untilAsked();
    if (!_stillWatching(machine, tools) || fleet.reachability != Reachability.connected) return;
    await tools.run(() async {
      switch (section) {
        case MachineSection.vault:
        case MachineSection.managing:
          await tools.vault.lookAt(fleet.backend, machine.name);
        case MachineSection.credentials:
          await tools.connections.lookAt(fleet.backend, machine.name);
        case MachineSection.agents:
          await tools.inventory.load(fleet.backend);
          if (_stillWatching(machine, tools)) await tools.authentication.look(fleet.backend);
        case MachineSection.health:
          await tools.readiness.look(fleet.backend);
        case MachineSection.tasks:
        case MachineSection.projects:
          break;
      }
    });
    if (!_stillWatching(machine, tools)) return;
    final read = switch (section) {
      MachineSection.vault || MachineSection.managing => tools.vault.state != null && tools.vault.problem == null,
      MachineSection.credentials => tools.connections.problem == null,
      MachineSection.agents =>
        tools.inventory.asked && tools.inventory.problem == null && tools.authentication.problem == null,
      MachineSection.health => tools.readiness.health != null && tools.readiness.problem == null,
      _ => false,
    };
    if (mounted && read) {
      setState(
        () =>
            _sectionReadAt[ShellPlace(Section.machine, machine: machine, machineSection: section).key] = DateTime.now(),
      );
    }
  }

  /// How this person stands in each project, which decides whether they may move its work.
  late final ProjectStandings _standings = ProjectStandings(widget.organizationSource);

  void _readStandings() => unawaited(_standings.read());

  Timer? _refreshing;
  int _refreshingEvery = -1;
  int _organizationPageRefresh = 0;

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
  Future<void> _refreshAll({bool quietly = false}) =>
      quietly ? _forgeTrust.quietly(() => _readAll(quietly: true)) : _readAll();

  late final _forgeTrust = ForgeTrustAsking((host) => trustOrganizationForge(context, host));

  Future<void> _readAll({bool quietly = false}) async {
    final identity = widget.identity;
    if (widget.shell.section == Section.organization && identity != null && !identity.busy) await identity.load();
    if (!mounted) return;
    await _standings.read();
    if (!mounted) return;
    // refresh() first forgets the answers it kept; the quiet timer leaves the store alone.
    if (!quietly) {
      await _organization?.refresh();
      if (!mounted) return;
      setState(() => _organizationPageRefresh++);
    }
    // A key loaded into the agent, or revoked, since the last read changes what a host admin is offered.
    await widget.hostAccess?.readAgain();
    if (!mounted) return;
    for (final machine in widget.machines.all.toList()) {
      if (!widget.machines.all.contains(machine)) continue;
      final fleet = widget.machines.of(machine);
      if (fleet.reachability != Reachability.connected) continue;
      await fleet.refresh(quietly: quietly || fleet != _fleet);
      if (!mounted) return;
    }
    if (!mounted) return;
    final machine = _toolMachine;
    final fleet = widget.machines.of(machine);
    if (fleet.reachability == Reachability.connected) {
      final tools = _toolsFor(machine);
      await tools.run(() => tools.vault.lookAt(fleet.backend, machine.name));
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
    // A session on screen holds the keyboard as much as anything opened over the frame.
    final open = widget.shell.anythingOpen || (widget.sessions.any && _runningIsShown);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open) {
        _openedFocus.requestFocus();
      } else if (!_frameFocus.hasFocus) {
        _frameFocus.requestFocus();
      }
    });
  }

  Machine? get _machinePlaceOwner {
    final place = widget.shell.place;
    final machine = place.machine;
    return place.section == Section.machine &&
            machine != null &&
            widget.machines.all.contains(machine) &&
            !_hostRuns.preparing.any((run) => run.name == machine.name)
        ? machine
        : null;
  }

  List<Command> _commands() {
    final machine = _machinePlaceOwner;
    final scoped = <String, Command>{
      if (machine != null)
        for (final command in [..._machineMenu(on: machine), _machinePanic(machine)]) command.id: command,
    };
    final all = _unscopedCommands();
    final ids = all.map((command) => command.id).toSet();
    return [
      for (final command in all) scoped[command.id] ?? _commandForItem(command).unless(_itemScopeProblem(command)),
      for (final command in scoped.values)
        if (!ids.contains(command.id)) command,
    ];
  }

  Command _commandForItem(Command command) {
    if (command.id != 'project.default' ||
        widget.shell.section != Section.project ||
        widget.shell.itemProject != defaultProject ||
        widget.shell.itemMachine != widget.machines.current) {
      return command;
    }
    final project = projectsOnMachine(
      widget.machines,
      widget.machines.current,
    ).singleWhere((project) => project.name == defaultProject);
    return _pageProjectCommands(
      widget.machines.current,
      project,
    ).singleWhere((command) => command.id == 'project.default');
  }

  String? _itemScopeProblem(Command command) {
    final scoped =
        {
          Home.machineTitle,
          Home.machineMenu,
          Home.projectMenu,
          Home.repositoryRow,
          Home.startTile,
          Home.templateTile,
        }.contains(command.home) ||
        command.id == 'project.default' ||
        command.id == 'detail.open' ||
        command.id.startsWith('work.') ||
        command.id.startsWith('vault.') ||
        command.id.startsWith('machine.') ||
        command.id.startsWith('agents.');
    if (scoped &&
        {Section.machine, Section.project}.contains(widget.shell.section) &&
        widget.shell.itemMachine != null &&
        (_pageMachine(widget.shell.itemMachine!) != widget.machines.current ||
            _hostRuns.preparing.any((run) => run.name == widget.shell.itemMachine!.name))) {
      return 'Open this machine again before running its commands.';
    }
    if (scoped &&
        widget.shell.section == Section.project &&
        widget.shell.itemProject != null &&
        widget.shell.itemProject != _fleet.selectedProject?.name &&
        !(widget.shell.itemProject == defaultProject && _fleet.selectedProject == null)) {
      return 'Open this project again before running its commands.';
    }
    return null;
  }

  List<Command> _unscopedCommands() => commandsFor(
    viewActions: [
      ..._viewActions(),
      ..._organizationFactsCommands(),
      myKeyCommand(open: () => unawaited(showIdentity(context, model: widget.identity))),
    ],
    fleet: _fleet,
    machine: widget.machines.current,
    hostRuns: _hostRuns,
    hostActions: [
      ..._hostCommands(widget.machines.current),
      for (final run in _hostRuns.preparing) ..._preparationCommands(run),
    ],
    canForget: widget.machines.all.length > 1 && !widget.machines.current.isAlwaysListed,
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
    certifyAgain: (task) => unawaited(_certifyAgain(task)),
    unlockTheVault: _canUnlockHere ? () => unawaited(_unlockHere()) : null,
    openTheGate: _openTheGate,
    openEgress: _openEgress,
    removeWhatWasBuilt: _removeWhatWasBuilt,
    whyNoRemoval: _whyNoRemoval(widget.machines.current, _fleet.selectedProject?.name ?? ''),
    clearTheProject: _clearTheProject,
    startTheAgents: switch (_fleet.selectedProject?.project.name) {
      final name? => () => unawaited(_startTheAgents(name)),
      null => null,
    },
    checkTheMachine: _checkTheMachine,
    startThenCheck: () => unawaited(_startThenCheck()),
    showTheProviders: _showTheProviders,
    prepareTheProject: _prepareTheProject,
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
    showDestinations: _showDestinations,
    startFromTemplate: _startFromTemplate,
    stopEverything: _stopEverything,
    stopEverywhere: _stopEverywhere,
    watchAnotherMachine: _addAMachine,
    prepareServer: _openPrepare,
    startTheDaemon: () => unawaited(_startTheDaemon()),
    stopTheDaemon: () => unawaited(_stopTheDaemon()),
    forget: _forget,
    clearTheMachine: _clearTheMachine,
    showAbout: _showAbout,
    refreshAll: () => unawaited(_refreshAll()),
    anyAnswering: widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected),
    vault: _vault,
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
    final signIn = switch (widget.shell.opened) {
      OperationOpened(:final id) => _signInsAfterAFailedStart[id],
      _ => null,
    };
    final signingIn = <Command>[
      if (signIn != null) ...[signInCommand(signIn), importTheSignInCommand(signIn), signInAnywayCommand(signIn)],
    ];
    final run = _openedRun;
    if (run != null) {
      return [
        leaveWorkCommand(widget.shell.close, unavailable: run.operation.running ? 'the start is still running' : null),
        _restartCommand(run),
        ...signingIn,
      ];
    }
    return signingIn;
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

  /// The menu belongs to its named machine, including its availability reasons and delayed actions.
  List<Command> _machineMenu({Machine? on}) {
    final machine = on ?? widget.machines.current;
    final fleet = widget.machines.of(machine);
    final vault = _toolsFor(machine).vault;
    final commands = machineCommands(
      fleet: fleet,
      machine: machine,
      hostRuns: _hostRuns,
      hostActions: _hostCommands(machine),
      canForget: widget.machines.all.length > 1 && !machine.isAlwaysListed,
      reachedOverSsh: machine.needsATunnel,
      canStart: machine.canBeStartedHere,
      checkTheMachine: () => unawaited(_checkTheMachine(on: machine)),
      startThenCheck: () => unawaited(_startThenCheck(on: machine)),
      showTheProviders: () => unawaited(_showTheProviders(on: machine)),
      showTheVault: () => unawaited(_showTheVault(on: machine)),
      showConnections: () => unawaited(_showConnections(on: machine)),
      showDestinations: () => _showDestinations(on: machine),
      showAgents: () => unawaited(_showAgents(on: machine)),
      startTheDaemon: () => unawaited(_startTheDaemon(on: machine)),
      stopTheDaemon: () => unawaited(_stopTheDaemon(on: machine)),
      forget: () => unawaited(_forget(on: machine)),
      clearTheMachine: () => unawaited(_clearTheMachine(on: machine)),
      vault: vault,
      actOnTheVault: (act) => unawaited(_actOnTheVault(act, on: machine)),
      addAUser: () => unawaited(_addAUser()),
      unlockWithThePassphrase: unlockCommandFor(machine) != null ? () => unawaited(_unlockMachine(machine)) : null,
      makeTheVault: makeCommandFor(machine) != null ? () => unawaited(_makeTheVault(on: machine)) : null,
    );
    return [
      for (final command in commands)
        if (command.id == 'fleet.refresh')
          Command(
            id: command.id,
            label: command.label,
            group: command.group,
            home: command.home,
            shortcut: command.shortcut,
            run: () => unawaited(_refreshMachine(machine)),
          )
        else
          command,
    ];
  }

  Future<void> _refreshMachine(Machine machine) async {
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    await fleet.refresh();
    if (!_stillWatching(machine, tools) || fleet.reachability != Reachability.connected) return;
    await tools.run(() => tools.vault.lookAt(fleet.backend, machine.name));
  }

  Command _machinePanic(Machine machine) => Command(
    id: 'machine.panic',
    label: 'Stop everything on this machine',
    group: 'Machine',
    home: Home.machineTitle,
    shortcut: const SingleActivator(LogicalKeyboardKey.period, control: true, shift: true),
    unavailable: notAnswering(widget.machines.of(machine)),
    run: () => unawaited(_stopEverything(on: machine)),
  );

  Widget _vaultButtonsFor(Machine machine, FleetModel fleet, Vault vault) => VaultButtons(
    vault: vault,
    onLock: fleet.reachability == Reachability.connected
        ? () => unawaited(_actOnTheVault(vault.lockDoes, on: machine))
        : null,
    onOpenWithThePassphrase: fleet.reachability == Reachability.connected && unlockCommandFor(machine) != null
        ? () => unawaited(_unlockMachine(machine))
        : null,
    onMakeIt: fleet.reachability == Reachability.connected && makeCommandFor(machine) != null
        ? () => unawaited(_makeTheVault(on: machine))
        : null,
  );

  List<Command> _hostCommands(Machine machine) {
    final run = _hostRuns.of(machine.hostProject);
    return [
      if (widget.machines.all.contains(machine) && !machine.isAlwaysListed)
        connectionCommand(
          machine: machine,
          run: () => unawaited(
            machine.disconnected ? widget.machines.reconnect(machine) : widget.machines.disconnect(machine),
          ),
        ),
      if (widget.machines.all.contains(machine) &&
          machine.kind == 'host' &&
          widget.settings.hostUp(machine.hostProject) != null)
        runHostSetupAgainCommand(project: machine.hostProject, hostRuns: _hostRuns),
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

  List<Command> _preparationCommands(HostPreparation run) => [
    run.needsYou && !run.ready
        ? hostPreparationCommand(project: run.project, open: () => unawaited(_openHostRun(run)), home: Home.machineRow)
        : hostProtocolCommand(project: run.project, open: () => unawaited(_openHostRun(run))),
    ...hostRecoveryCommands(
      run: run,
      access: _hostRuns.hostAccess,
      goOn: () => unawaited(_hostRuns.resume(run)),
      takeDown: () => unawaited(
        openHostTakeDownDialog(
          context,
          project: run.project,
          machines: widget.machines,
          settings: widget.settings,
          hostRuns: _hostRuns,
          readHostProgress: _readHostProgress,
          openTerminal: widget.sessions.openTerminal,
          removeFromOrganization: _removeFromOrganization,
        ),
      ),
    ),
  ];

  Future<void> _takeDown(Machine machine) async {
    await openHostTakeDownDialog(
      context,
      project: machine.hostProject,
      machines: widget.machines,
      settings: widget.settings,
      hostRuns: _hostRuns,
      readHostProgress: _readHostProgress,
      openTerminal: widget.sessions.openTerminal,
      removeFromOrganization: _removeFromOrganization,
    );
    if (mounted && !widget.machines.all.contains(machine)) widget.shell.goTo(Section.machines);
  }

  /// What a confirmed take-down asks of the organization, wherever it was opened: its machine off the list.
  Future<String?> Function(String host)? get _removeFromOrganization => switch (_organization) {
    final organization? => (host) => organization.write(OrganizationChange.removeHost, {'host': host}),
    null => null,
  };

  Future<HostProgress> _readHostProgress(String host) async {
    final connections = _hostConnections;
    if (connections == null || !connections.connected(host)) {
      throw const OrganizationRefused('The machine is not connected.');
    }
    return connections.progress(host);
  }

  /// A machine's row under *Organization*: with nothing kept here, the organization's card is what it goes by.
  Command _takeOffCommand(OrganizationHost host) {
    final access = _hostRuns.hostAccess!;
    final kept = widget.settings.hostUp(host.name);
    return organizationCommand(
      id: 'takeOff/${host.name}',
      label: kept?.isRental == true ? 'Return this rental…' : 'Take Porelo off this machine…',
      danger: true,
      unavailable: access.whyNotTakeDown(host.name) ?? (kept == null ? access.whatTakingOffLacks(host) : null),
      run: () => unawaited(
        openHostTakeDownDialog(
          context,
          project: host.name,
          machines: widget.machines,
          settings: widget.settings,
          hostRuns: _hostRuns,
          fromTheCard: kept == null ? access.takingOffRecord(host) : null,
          readHostProgress: _readHostProgress,
          openTerminal: widget.sessions.openTerminal,
          removeFromOrganization: _removeFromOrganization,
        ),
      ),
    );
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
      whyNoRemoval: _whyNoRemoval(on ?? widget.machines.current, project.name),
      clearTheProject: _clearTheProject,
      showTheMessages: () => unawaited(_showTheMessages()),
      openItsForge: () => unawaited(_openItsForge()),
      itsForgeIsMissing: _itsForgeIsMissing(project),
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

  /// A tile's actions, judged on the tile's own machine and run with its work selected there.
  List<Command> _tileActions(Tile tile) => <Command>[
    seeItsDetailsCommand(run: _openWork).after(() => _actOn(tile)),
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
      certifyAgain: (task) => unawaited(_certifyAgain(task)),
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
    final name = tile.task?.name;
    _workView.showList(unfold: name == null ? null : WorkView.placeOf(tile.machine.name, name));
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

  Future<void> _openHostRun(HostPreparation run) => openHostRunDialog(
    context,
    run: run,
    hostRuns: _hostRuns,
    machines: widget.machines,
    settings: widget.settings,
    openTerminal: widget.sessions.openTerminal,
  );

  /// Clears the machine and removes its trusted message signer from its projects.
  Future<void> _clearTheMachine({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    await openClearing(context, MachineClearing(fleet.backend, _forges, machineName: machine.name));
    if (mounted && widget.machines.all.contains(machine)) unawaited(fleet.refresh(quietly: true));
  }

  /// Why [project] cannot be removed here, or null where Porelo lists it as registered here alone.
  String? _whyNoRemoval(Machine machine, String project) => !machine.isThisComputer
      // `project list` answers for this computer alone, and an equal name elsewhere says nothing of that project.
      ? 'Porelo on this computer cannot say whose a project on ${machine.name} is.'
      : _organization?.whyNoRemoval(project) ??
            (_organization == null ? 'Porelo cannot be asked here whose it is.' : null);

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
    if (widget.deleting.removed) {
      _organization?.readAnswersAgain();
      await fleet.refresh();
    }
  }

  /// Asks whether this machine can run anything, and shows what it said. Asked, never polled.
  Future<void> _checkTheMachine({Machine? on}) async {
    _goToMachineSection(MachineSection.health, on: on);
  }

  /// The person's forge login: the one the app was given, or the token this instance was started with, otherwise the
  /// platform's own keychain.
  late final ForgeConnection _forges =
      widget.forges ??
      ForgeConnection(
        EnvironmentForgeTokens(desk.environment, PlatformForgeTokens()),
        entries: _ForgesInSettings(widget.settings),
        openTerminal: widget.sessions.openTerminal,
      );

  /// The repositories this machine works on in the Default project, in `default`, and the projects asked
  /// again once it is put away: a repository added there is what lets work start in default.
  Future<void> _showTheDefault() async {
    await _askTheDefault();
    if (mounted) await _fleet.refresh(quietly: true);
  }

  /// Starts work in `default`: a repository named, or one worked on before, and work started on it.
  Future<void> _startInDefault() => _askTheDefault(
    onStartWork: (repository, checkout) => _startWorkIn(defaultProject, repository: repository, checkout: checkout),
  );

  Future<void> _askTheDefault({Future<void> Function(String repository, CheckoutHere? checkout)? onStartWork}) {
    // The machine that was asked: a project its first start names is that machine's, whichever is selected by then.
    final asked = widget.machines.current;
    return showTheDefault(
      context,
      machine: _fleet.backend,
      machineName: widget.machines.current.name,
      pickAtAForge: () async {
        ({ForgeRepository repository, Forge forge})? picked;
        await showRepositories(
          context,
          _forges,
          machine: _fleet.backend,
          machineName: widget.machines.current.name,
          usedBy: _usedBy,
          onPick: (repository, forge) => picked = (repository: repository, forge: forge),
        );
        return picked;
      },
      onStartWork: onStartWork,
      thisComputer: asked.isThisComputer,
      onStartProject: (project, notes, checkout) async {
        if (widget.machines.current != asked) widget.machines.select(asked);
        await _startWorkIn(project, notes: notes, checkout: checkout);
      },
    );
  }

  /// [project]'s address as last read, empty where none is known: it then matches no forge.
  ///
  /// Called while the forge pages are drawn; [Organization.addressOf] reads each project once, one at a time.
  String _addressOf(String project) =>
      project == defaultProject ? '' : _organization?.addressOf(project)?.address ?? '';

  /// Why [project]'s forge cannot be opened from here, or null where it can, or where pressing it will find out.
  ///
  /// Only the selected project's address is read for this: every row's menu is built on every frame.
  String? _itsForgeIsMissing([ProjectOnScreen? project]) {
    final name = (project ?? _fleet.selectedProject)?.name;
    if (name == null) return null;
    if (name == defaultProject) return 'it has no repository of its own';
    final organization = _organization;
    if (organization == null) return 'its address cannot be asked for here';
    final known = organization.addressOf(name, ask: name == _fleet.selectedProject?.name);
    return known == null ? null : _whyNoForgeFor(known);
  }

  /// Why [known] leads to no forge set up here, or null where it leads to one.
  String? _whyNoForgeFor(KnownAddress known) {
    if (known.problem case final problem?) return 'its address could not be read: $problem';
    final url = known.address;
    if (url == null || url.isEmpty) return 'it has no address yet';
    if (fullNameOf(url) == null) return 'its repository is not on a forge';
    if (_forges.holding(url) == null) {
      return 'its repository is on ${hostOf(url) ?? 'a forge'}, which is not set up here';
    }
    return null;
  }

  /// The selected project at its forge and on this machine: changes waiting here.
  Future<void> _openItsForge() async {
    final name = _fleet.selectedProject?.name;
    final organization = _organization;
    if (name == null || organization == null) return;
    final known = await organization.readAddress(name);
    if (_whyNoForgeFor(known) case final why?) {
      _fleet.say('$name: $why.');
      return;
    }
    final url = known.address!;
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
      // The organization's project admits only its own logins to its room, as the machine refuses any other.
      admission: () => roomAdmission(
        project.name,
        machine: widget.machines.current,
        organizationRead: _organization == null || _organization.noOrganization || _organization.view != null,
        view: _organization?.view,
        problem: _organization?.problem,
      ),
      admissionChanges: _organization,
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
  Future<void> _restoreTheMirror({required bool force, Machine? on}) async {
    final fleet = widget.machines.of(on ?? widget.machines.current);
    await widget.backups.restore(fleet.backend, force: force);
    final said = widget.backups.restoreWords;
    if (said.isNotEmpty) fleet.say(said);
  }

  /// Asks the upstream how far behind this project is, now.
  ///
  /// [repository] is one of the project's; without one, the project's own.
  Future<void> _syncTheUpstream({String? repository}) async {
    final project = _fleet.selectedProject;
    if (project == null) return;
    final said = await widget.backups.syncFor(
      _fleet.backend,
      project.name,
      repository: repository,
      joinedHost: widget.machines.current.hostCard != null,
    );
    // Refreshed first: a refresh announces itself, and the answer should be said last.
    await _fleet.refresh();
    if (said.isNotEmpty) _fleet.say(said);
  }

  /// Removes the backup being considered, and says what that did.
  Future<void> _removeTheBackup({Machine? on}) async {
    final fleet = widget.machines.of(on ?? widget.machines.current);
    await widget.backups.remove(fleet.backend);
    final said = widget.backups.words;
    if (said.isNotEmpty) fleet.say(said);
  }

  /// Shows how the current machine connects out.
  Future<void> _showConnections({Machine? on}) async {
    _goToMachineSection(MachineSection.credentials, on: on);
  }

  void _showDestinations({Machine? on}) {
    final machine = on ?? widget.machines.current;
    _goToMachineSection(MachineSection.credentials, on: machine);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final there = _destinationCards[machine]?.currentContext;
      if (there != null && there.mounted) unawaited(Scrollable.ensureVisible(there));
    });
  }

  /// Asks step by step what to declare, declares it, and brings its value to the machine the way
  /// the wizard settled on. What stays on the view afterwards is the way to try the value again.
  Future<void> _addAConnection({String match = '', Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final connections = tools.connections;
    final backend = fleet.backend;
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
      makeTheVault: makeCommandFor(machine) != null ? () => _makeTheVault(on: machine) : null,
      openTheVault: unlockCommandFor(machine) != null ? () => _unlockMachine(machine) : null,
    );
    if (asked == null || !_stillWatching(machine, tools)) return;
    await tools.run(
      () => connections.declare(
        backend,
        kind: asked.kind,
        match: asked.match,
        id: asked.id,
        user: asked.user,
        purpose: asked.purpose,
        source: asked.source,
        fromFile: asked.fromFile,
      ),
    );
    if (!_stillWatching(machine, tools) || connections.declared == null) return;
    switch (asked.storing) {
      case Storing.nothing:
        break;
      case Storing.sendTheKey:
        final refused = await _sendAKey(pasted: asked.key, on: machine);
        if (refused != null) fleet.say(refused);
      case Storing.onTheMachine:
        await _storeOnTheMachine(on: machine);
      case Storing.inATerminal:
        await _storeInATerminal(on: machine);
    }
  }

  /// Runs the declared store command on the machine, which reads the value from its own disk.
  Future<void> _storeOnTheMachine({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final connections = tools.connections;
    final declared = connections.declared;
    final command = declared == null ? null : onTheMachine(machine, declared.storeCommand, terminal: false);
    if (command == null) return;
    final failed = await widget.machines.setup.storeOnTheMachine(command, '');
    if (!_stillWatching(machine, tools)) return;
    fleet.say(
      failed == null
          ? 'The key for ${declared!.connection.match} is in the vault on ${machine.name}.'
          : 'Copying the key into the vault did not work: $failed',
    );
    if (failed == null) await tools.run(() => connections.lookAt(fleet.backend, machine.name));
  }

  /// Stores the declared value by typing it into a terminal on the machine, then reads again.
  Future<void> _storeInATerminal({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final connections = tools.connections;
    final declared = connections.declared;
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
    if (!_stillWatching(machine, tools)) return;
    await tools.run(() => connections.lookAt(fleet.backend, machine.name));
  }

  /// Sends a key to the declared store command on its standard input: a file of this computer's,
  /// read at the moment it is sent, or what was pasted. Held for that moment and nowhere after.
  /// Answers why nothing was stored, or null once it was.
  Future<String?> _sendAKey({String? file, String? pasted, Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return 'This machine is no longer watched.';
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final connections = tools.connections;
    final declared = connections.declared;
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
    if (!_stillWatching(machine, tools)) return null;
    if (failed != null) {
      fleet.say('Storing the key did not work: $failed');
      return 'Storing the key did not work: $failed';
    }
    fleet.say('The key for ${declared.connection.match} is stored on ${machine.name}.');
    await tools.run(() => connections.lookAt(fleet.backend, machine.name));
    return null;
  }

  /// Makes the current machine's vault by a passphrase chosen in a terminal there, then asks the
  /// machine whether it is there — the terminal's exit code is not the verdict.
  Future<void> _makeTheVault({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final vault = tools.vault;
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
    if (!_stillWatching(machine, tools)) return;
    await tools.run(() => vault.lookAt(fleet.backend, machine.name));
  }

  /// Whether the current machine's own `porelo` can be reached for a terminal.
  bool get _canUnlockHere => unlockCommandFor(widget.machines.current) != null;

  /// Whether the current machine's vault can be made here: never a rented server's, which its setup makes.
  bool get _canMakeHere => makeCommandFor(widget.machines.current) != null;

  /// Grants what [credential] names, then asks the vault again: the grant is kept there.
  Future<void> _grant(Credential credential, {Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final vault = tools.vault;
    await showGranting(context, Granting(fleet.backend, machine, credential.name));
    if (!_stillWatching(machine, tools)) return;
    await tools.run(() => vault.lookAt(fleet.backend, machine.name));
  }

  /// Opens the current machine's vault by its passphrase, in a terminal on that machine, then asks
  /// the machine whether it is open — the terminal's exit code is not the verdict.
  Future<void> _unlockHere() async {
    await _unlockMachine(widget.machines.current);
  }

  VoidCallback? _unlockFor(Machine machine) =>
      unlockCommandFor(machine) == null ? null : () => unawaited(_unlockMachine(machine));

  Future<void> _unlockMachine(Machine machine) async {
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    final List<String>? command;
    try {
      command = unlockCommandFor(machine);
    } on FormatException catch (error) {
      fleet.say(error.message);
      return;
    } on HostFilesRefused catch (error) {
      fleet.say(error.message);
      return;
    }
    if (command == null) return;
    await unlockInATerminal(context, machine: machine, command: command, open: widget.sessions.openTerminal);
    if (!_stillWatching(machine, tools)) return;
    await tools.run(() => tools.vault.lookAt(fleet.backend, machine.name));
    if (!_stillWatching(machine, tools)) return;
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

  /// The forges set up on this computer.
  void _showTheForges() => widget.shell.goTo(Section.forges);

  /// Opens [entry]'s repositories as a page.
  Future<void> _openTheForge(ForgeEntry entry) async {
    widget.shell.goTo(Section.forge);
    if (_forges.current?.id != entry.id || !_forges.connected) await _forges.choose(entry);
  }

  /// The organization this computer reads, kept while the shell lives so that its last list outlives the page.
  /// Whether *Projects* shows those of the watched machines rather than the organization's own.
  bool _machineProjects = false;

  /// The host whose page is open under *Machines*, where this computer reads an organization.
  String? _organizationHost;

  /// The exact list to return to after opening an organization machine.
  ShellPlace? _organizationHostFrom;

  /// The exact list to return to after opening an organization project.
  ShellPlace? _organizationProjectFrom;

  late final Organization? _organization = widget.organizationSource == null
      ? null
      : (Organization(widget.organizationSource!)
          // Only the real organization asks this computer's vault: a stand-in's refusals are no vault's.
          ..thisComputersVaultShut = widget.organizationSource is PoreloOrganizationSource
              ? isThisComputersVaultShut
              : null
          ..openThisComputersVault = (() => _unlockMachine(Machine.local())));

  late final HostConnections? _hostConnections =
      widget.hostConnections ?? (_organization == null ? null : widget.connectionsFor?.call(_organization));

  /// The project whose page is open under *Projects*, where this computer reads an organization.
  String? _organizationProject;

  /// A person's own projects, and one's page, read from the organization.
  Widget _organizationProjects(Organization organization) => _organizationProject == null
      ? OrganizationProjectsPage(
          organization: organization,
          connections: _hostConnections,
          onProject: (name) => setState(() {
            _organizationProjectFrom = const ShellPlace(Section.projects);
            _organizationProject = name;
          }),
          onHost: (project, host) {
            final machine = widget.machines.all
                .where((machine) => machine.hostCard?.name == host || machine.name == host)
                .firstOrNull;
            // A Porelo older than the carried row lists a project only after a first start there; its page says so.
            if (machine != null && widget.machines.of(machine).projects.any((each) => each.name == project)) {
              _openPageProject(machine, project);
            } else {
              setState(() {
                _organizationHostFrom = const ShellPlace(Section.projects);
                _organizationHost = host;
              });
              widget.shell.goTo(Section.machines);
            }
          },
          menuFor: (project, host) {
            final machine = widget.machines.all.where((machine) => machine.hostCard?.name == host).firstOrNull;
            if (machine == null) return const [];
            return cardHostTransferCommands(
              transfers: _transfers,
              machine: machine,
              project: project,
              whyNoRight: _standings.whyNoRight(project),
              hasSecrets: centralToken(widget.settings.secretsFile, desk.environment) != null,
              running: _transfersRunning.contains('${machine.name}/$project'),
              start: (direction) => unawaited(_transferInATerminal(machine, project, direction)),
            );
          },
          onOthers: () => setState(() => _machineProjects = true),
        )
      : OrganizationProjectPage(
          key: ValueKey((_organizationProject, _organizationPageRefresh)),
          organization: organization,
          project: _organizationProject!,
          path: _organizationDetailPath(
            _organizationProjectFrom,
            const ShellPlace(Section.projects),
            _backFromOrganizationProject,
          ),
          connections: _hostConnections,
          onGiveToken: _giveHostToken,
          onBack: _backFromOrganizationProject,
        );

  /// The organization's people, projects, hosts and owners.
  /// A person's key commands, run through the terminal.
  late final _keys = KeyCommands(receipts: SettingsReceipts(widget.settings));

  Widget _organizationPage() {
    final organization = _organization;
    return _opened() ??
        (organization == null
            ? const SizedBox.shrink()
            // Read again as a preparation starts and ends, so a machine's row says it runs.
            : ListenableBuilder(
                listenable: _hostRuns,
                builder: (context, _) => OrganizationPage(
                  key: ValueKey(widget.shell.place.key),
                  section: widget.shell.place.organizationSection,
                  path: [
                    (label: 'Organizations', go: () => _chooseTreePlace(const ShellPlace(Section.organizations), true)),
                    (
                      label: organization.view?.name ?? 'Organization',
                      go: () => _chooseTreePlace(
                        ShellPlace(Section.organization, organization: organization.view?.name ?? 'Organization'),
                        true,
                      ),
                    ),
                  ],
                  settings: widget.settings,
                  organization: organization,
                  identity: widget.identity,
                  connections: _hostConnections,
                  onGiveToken: _giveHostToken,
                  onPrepare: _prepareThisMachine,
                  preparing: _preparingFor,
                  onProtocol: (run) => unawaited(_openHostRun(run)),
                  prepareMachine: _commands()
                      .where((command) => command.id == 'host.prepare' && command.visible)
                      .firstOrNull,
                  takeOff: _hostRuns.hostAccess == null ? null : _takeOffCommand,
                  keys: _keys,
                  onProject: (name) {
                    setState(() {
                      _organizationProjectFrom = widget.shell.place;
                      _organizationProject = name;
                    });
                    widget.shell.goTo(Section.projects);
                  },
                  onHost: (host) {
                    final machine = widget.machines.all.where((machine) => machine.hostCard?.name == host).firstOrNull;
                    if (machine != null) return _openPageMachine(machine, from: widget.shell.place);
                    setState(() {
                      _organizationHostFrom = widget.shell.place;
                      _organizationHost = host;
                    });
                    widget.shell.goTo(Section.machines);
                  },
                ),
              ));
  }

  /// The selected machine's vault, where a forge's token is stored.
  ForgeTokenVault get _forgeTokenVault => ForgeTokenVault(
    machine: widget.machines.current,
    answers: _fleet.reachability == Reachability.connected,
    open: widget.sessions.openTerminal,
  );

  /// What the machine shown declares it connects out with, read with its vault; another machine's never.
  List<Connection> get _heldConnections => _vault.about == widget.machines.current.name
      ? _vault.state?.connections ?? const <Connection>[]
      : const <Connection>[];

  /// Every forge set up here, as a page beside Machines and Projects. The machine's vault is read for it too, since
  /// the forges it already holds are listed from it.
  Widget _forgesPage() {
    _keepTheVaultButtonTrue(widget.machines.current, _fleet);
    return _forgesPageItself();
  }

  Widget _forgesPageItself() =>
      _opened() ??
      _explained(
        'forges',
        'My forges',
        const <({String title, String words})>[
          (
            title: 'What is in My forges?',
            words: 'Where your repositories are, each reached with a token kept in this computer\'s keychain.',
          ),
        ],
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_fleet, _vault]),
          builder: (context, _) => ForgesPage(
            forges: _forges,
            held: _heldConnections,
            heldOn: widget.machines.current.name,
            organizationForge: organizationForgeAddress(_organization?.view),
            usedBy: _usedBy,
            onMachine: (name) {
              final machine = widget.machines.all.where((machine) => machine.name == name).firstOrNull;
              if (machine != null) _openPageMachine(machine);
            },
            onOpen: (entry) => unawaited(_openTheForge(entry)),
            keyCheck: widget.forgeKeyCheck,
            tokenVault: _forgeTokenVault,
          ),
        ),
      );

  /// One forge's repositories, as a page.
  Widget _forgePage() {
    final machineAtOpen = widget.machines.current;
    return _opened() ??
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            for (final machine in widget.machines.all) widget.machines.of(machine),
          ]),
          builder: (context, _) => ForgePage(
            onBack: () => widget.shell.goTo(Section.forges),
            onMachine: (name) {
              final machine = widget.machines.all.where((machine) => machine.name == name).firstOrNull;
              if (machine != null) _openPageMachine(machine);
            },
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
            machineName: widget.machines.current.name,
            tokenVault: _forgeTokenVault,
            onOpenProject: (entry, fullName) => unawaited(_openProjectOfRepository(entry, fullName)),
            usedOnAt: _machinesWorkingOnAt,
            onStartWork: (project) {
              widget.machines.select(machineAtOpen);
              return project == defaultProject ? _startInDefault() : _startWorkIn(project);
            },
          ),
        );
  }

  Future<void> _openProjectOfRepository(ForgeEntry entry, String fullName) async {
    final matches = <({Machine machine, ProjectOnScreen project})>[
      for (final machine in listedMachines(widget.machines))
        for (final project in projectsOnMachine(widget.machines, machine))
          if ((forgeHoldsUrl(entry, _addressOf(project.name)) && fullNameOf(_addressOf(project.name)) == fullName) ||
              project.project.repositoryStates.any(
                (repository) =>
                    forgeHoldsUrl(entry, repository.upstream) && fullNameOf(repository.upstream) == fullName,
              ))
            (machine: machine, project: project),
    ];
    if (matches.isEmpty) return;
    final chosen = matches.length == 1
        ? matches.single
        : await showDialog<({Machine machine, ProjectOnScreen project})>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Open the project on which machine?'),
              children: [
                for (final row in matches)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, row),
                    child: Text('${row.project.label} on ${row.machine.name}'),
                  ),
              ],
            ),
          );
    if (chosen != null && mounted) _openPageProject(chosen.machine, chosen.project.name);
  }

  List<String> _machinesWorkingOnAt(ForgeEntry entry, String fullName) => [
    for (final machine in widget.machines.all)
      if (widget.machines
          .of(machine)
          .projects
          .any(
            (project) =>
                (forgeHoldsUrl(entry, _addressOf(project.name)) && fullNameOf(_addressOf(project.name)) == fullName) ||
                project.project.repositoryStates.any(
                  (repository) =>
                      forgeHoldsUrl(entry, repository.upstream) && fullNameOf(repository.upstream) == fullName,
                ),
          ))
        machine.name,
  ];

  /// The watched machines on which the repository called [fullName] is worked on, or holds the
  /// settings of a project: by name, nothing else (walk 10).
  List<String> _machinesWorkingOn(String fullName) => <String>[
    for (final machine in widget.machines.all)
      if (widget.machines
          .of(machine)
          .projects
          .any(
            (each) =>
                fullNameOf(_addressOf(each.name)) == fullName ||
                each.project.repositoryStates.any((repository) => fullNameOf(repository.upstream) == fullName),
          ))
        machine.name,
  ];

  /// The repositories of the watched machines' projects on [entry]'s forge: what keys
  /// were given there, which removing the entry would leave without a way to take them off.
  List<String> _usedBy(ForgeEntry entry) => <String>{
    for (final machine in widget.machines.all)
      for (final project in widget.machines.of(machine).projects)
        for (final url in <String>[
          _addressOf(project.name),
          for (final each in project.project.repositoryStates) each.upstream,
        ])
          if (hostOf(url) == entry.address) ?fullNameOf(url),
  }.toList()..sort();

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
  Future<void> _showTheProviders({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    _goToMachineSection(MachineSection.agents, on: machine);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealProviders(machine));
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
  Future<void> _stopEverything({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final backend = widget.machines.of(machine).backend;
    widget.stopping.letItBe();
    unawaited(widget.stopping.consider(backend));
    await openEmergencyStop(
      context,
      stopping: widget.stopping,
      onStopEverything: () => widget.stopping.stopEverything(backend),
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
  Future<void> _showTheVault({Machine? on}) async {
    _goToMachineSection(MachineSection.vault, on: on);
  }

  /// Which machine, and in which state, the vault's button was last asked about.
  final _vaultAskedFor = <Machine, Reachability>{};

  /// Asks the machine in the title about its store whenever it becomes the one shown or answers
  /// again, so the button beside the stop is never a guess.
  void _keepTheVaultButtonTrue(Machine machine, FleetModel fleet) {
    if (_vaultAskedFor[machine] == fleet.reachability) return;
    _vaultAskedFor[machine] = fleet.reachability;
    if (fleet.reachability != Reachability.connected) return;
    final tools = _toolsFor(machine);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stillWatching(machine, tools) && identical(widget.machines.of(machine), fleet)) {
        unawaited(tools.run(() => tools.vault.lookAt(fleet.backend, machine.name)));
      }
    });
  }

  /// Enrolls this device, opens the store with it, or shuts it: the button's act, or a menu's.
  Future<void> _actOnTheVault(VaultAct act, {Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final tools = _toolsFor(machine);
    final vault = tools.vault;
    final backend = widget.machines.of(machine).backend;
    final storage = vault.devices.store.storage;
    String devicesSaid() => !_stillWatching(machine, tools)
        ? '${machine.name} is no longer watched.'
        : vault.devices.problem ?? vault.devices.said ?? '';
    Future<void> runIfWatching(Future<void> Function() action) async {
      if (!_stillWatching(machine, tools)) return;
      await tools.run(action);
    }

    await showDialog<void>(
      context: context,
      builder: (context) => switch (act) {
        VaultAct.enroll => EnrollDialog(
          storage: storage,
          suggested: _hostName(),
          onEnroll: (name) => runIfWatching(() => vault.devices.enroll(backend, name)),
          answer: devicesSaid,
        ),
        VaultAct.open => OpenDialog(
          onOpen: (minutes) => runIfWatching(() async {
            await vault.devices.unlock(backend, minutes: minutes);
            if (_stillWatching(machine, tools)) await vault.look(backend);
          }),
          answer: devicesSaid,
        ),
        VaultAct.shut => ShutDialog(
          onShut: () => runIfWatching(() => vault.lock(backend)),
          answer: () => !_stillWatching(machine, tools)
              ? '${machine.name} is no longer watched.'
              : vault.problem ?? vault.shut?.words ?? '',
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
  Future<void> _showAgents({Machine? on}) async {
    _goToMachineSection(MachineSection.agents, on: on);
  }

  /// Stops watching the machine being acted on, and goes back to what needs a person.
  /// What forgetting a machine does, said before it is done.
  static const _forgetting =
      'This interface stops watching it and takes down the tunnel it raised to it. Nothing on the machine '
      'changes: its Porelo, its work and its vault stay as they are, and Watch another machine… adds it again.';

  /// Whether forgetting [machine] needs a warning: it is this person's to look after, by the organization or by having
  /// set it up here. Anyone else's server is simply taken off their own list.
  bool _warnsOnForgetting(Machine machine) {
    if (machine.kind != 'host') return false;
    final view = _organization?.view;
    final card = view?.hosts.where((host) => host.name == machine.hostCard?.name).firstOrNull;
    return card == null || card.admins.contains(view!.me) || widget.settings.hostUp(machine.hostProject) != null;
  }

  Future<void> _forget({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    if (widget.machines.all.length < 2 || machine.isAlwaysListed) return;
    if (_warnsOnForgetting(machine)) {
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
                    'It keeps running, and stands on under Organization. A rented one goes on billing at its provider.',
                  ),
                  if (takeDown.unavailable != null) Text('This action is unavailable: ${takeDown.unavailable}'),
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
    final selected = _fleet.selectedProject?.project;
    if (selected == null) return;
    final why = await _takeIfCarried(selected.name);
    if (!mounted) return;
    if (why != null) return _fleet.say(why);
    final project = _listed(selected.name) ?? selected;
    // Open at once and read behind it: waiting for the machine first left the press unanswered.
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.openFrom(_fleet.backend, project, job));
    unawaited(_offerWhatTheHostHas(project.name));
    await _offerToStart();
  }

  /// Starts work in the selected project.
  Future<void> _startWork({String? repository, VoidCallback? onChangeProject}) async {
    final selected = _fleet.selectedProject?.project;
    if (selected == null) return;
    // In default, work starts on a repository named first: the one way, wherever it is asked for.
    if (selected.name == defaultProject) return _startInDefault();
    final why = await _takeIfCarried(selected.name);
    if (why != null) return _fleet.say(why);
    final project = _listed(selected.name);
    if (project == null || !mounted) return;
    // Open at once and read behind it: waiting for the machine first left the press unanswered.
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.open(_fleet.backend, project, repository: repository));
    unawaited(_offerWhatTheHostHas(project.name));
    await _offerToStart(onChangeProject: onChangeProject);
  }

  /// The other machines where work of the project called [name] runs, as each last said.
  List<String> _runningElsewhere(String name) => <String>[
    for (final machine in widget.machines.all)
      if (machine != widget.machines.current &&
          widget.machines.of(machine).tasks.any((task) => task.running && task.project == name))
        machine.name,
  ];

  Project? _listed(String name, {FleetModel? on}) =>
      (on ?? _fleet).projects.where((each) => each.project.name == name).firstOrNull?.project;

  /// Takes [name] if this machine carries it and this person has not taken it yet, at a person's act: a list never
  /// does, as a take fetches and may ask a token. Answers why it could not be, in words, or null.
  ///
  /// On [on], the machine acted on unless another is named.
  Future<String?> _takeIfCarried(String name, {FleetModel? on}) async {
    final fleet = on ?? _fleet;
    if (_listed(name, on: fleet)?.carried != true) return null;
    final String words;
    try {
      final taken = await fleet.backend.takeProject(name);
      if (taken.taken) {
        await fleet.refresh(quietly: true);
        return null;
      }
      words = taken.words.isEmpty ? 'The machine did not say why.' : taken.words;
    } on FeatureNotSupported {
      return 'This machine carries $name, and starting there from here needs a newer Porelo on it.';
    } on VarlinkException catch (refused) {
      return '$name could not be taken on this machine: ${refused.simpleName}';
    } on VarlinkDisconnected {
      return '$name could not be taken: the connection to this machine was lost.';
    }
    return '$name could not be taken on this machine: $words';
  }

  /// Starts work in [project] from a machine's page: taken first if need be. Answers why it cannot start, or null.
  Future<String?> _startFromTheMachinePage(String host, String project) async {
    await _fleet.refresh(quietly: true);
    if (_fleet.reachability != Reachability.connected) {
      return '$host is not answering, so work in $project cannot start from here now.';
    }
    if (_listed(project) == null) {
      return '$host does not list $project yet. It reads the organization every few minutes; an older Porelo '
          'there lists a project only after a first start. On the machine, '
          'porelo task prepare -p $project --dry-run takes it.';
    }
    final why = await _takeIfCarried(project);
    if (why != null) return why;
    final cannot = StartWork.whyNot(_listed(project));
    if (cannot != null) return '$project cannot start on $host: $cannot.';
    unawaited(_startWorkIn(project));
    return null;
  }

  /// Starts work in the project called [name], once the machine lists it: what binding a machine
  /// from a repository leads to.
  ///
  /// [notes] are what a checkout's plugins said, whose dialog has gone: said here, and with any reason it stops.
  Future<void> _startWorkIn(
    String name, {
    String? repository,
    List<String> notes = const <String>[],
    CheckoutHere? checkout,
  }) async {
    final said = notes.join(' ');
    if (said.isNotEmpty) _fleet.say(said);
    String withNotes(String words) => said.isEmpty ? words : '$words $said';
    Project? listed() => _listed(name);
    final why = await _takeIfCarried(name);
    if (!mounted) return;
    if (why != null) return _fleet.say(withNotes(why));
    // Asked of the machine first only when it is not known yet: a round trip before the form opened
    // was a pause a person noticed.
    final known = listed();
    if (known == null || (repository != null && !known.repositories.contains(repository))) {
      await _fleet.refresh(quietly: true);
    } else {
      unawaited(_fleet.refresh(quietly: true));
    }
    final project = listed();
    if (!mounted) return;
    if (project == null) {
      return _fleet.say(
        withNotes('${widget.machines.current.name} does not list $name, so work in it cannot start from here now.'),
      );
    }
    // The project the work starts in is the one shown in the tree: a project made from a repository
    // appeared there unselected, and the person looked for it (walk 8).
    if (name != defaultProject) {
      _fleet.selectProject(name);
      widget.shell.goTo(Section.project);
    }
    widget.starting.publishedHostKeys = _publishedHostKeys;
    widget.starting.runningElsewhere = _runningElsewhere(project.name);
    unawaited(widget.starting.open(_fleet.backend, project, checkout: checkout));
    if (repository != null) widget.starting.chooseRepository(repository);
    unawaited(_offerWhatTheHostHas(project.name));
    await _offerToStart();
  }

  /// On an organization's machine, offers only the repositories of [project] it has taken, and says why not the
  /// others; where it cannot be asked, says so, and every one stays offered. One the machine's own Porelo says it
  /// does not carry is never offered.
  Future<void> _offerWhatTheHostHas(String project) async {
    final starting = widget.starting;
    // What the machine's own daemon says it does not carry is never offered, whatever the host says after: a start
    // there is refused.
    final notCarried = <String>{
      for (final each in starting.project?.repositoryStates ?? const <Repository>[])
        if (each.carriedHere == false && starting.project?.name == project) each.name,
    };
    final notCarriedWords = switch (notCarried.length) {
      0 => null,
      1 => 'The machine does not carry ${notCarried.single}, and would refuse a start there.',
      final n => 'The machine does not carry $n of the repositories, and would refuse a start there.',
    };
    void offerOnly(Set<String> names, String? words) => starting.offerOnly(
      names.difference(notCarried),
      [?words, ?notCarriedWords].isEmpty ? null : [?words, ?notCarriedWords].join(' '),
    );
    if (notCarried.isNotEmpty) offerOnly(starting.project!.workRepositories.toSet(), null);
    final host = widget.machines.current.hostCard?.name;
    final connections = _hostConnections;
    if (host == null || connections == null || project == defaultProject) return;
    // The form's own machine, which the question is about, whichever is chosen meanwhile.
    final on = starting.openedOn;
    if (!connections.connected(host)) {
      starting.notOfferedWords = '$host was not asked which repositories it has taken, so every one is offered.';
      return offerOnly(starting.project?.workRepositories.toSet() ?? const <String>{}, starting.notOfferedWords);
    }
    final HostProgress progress;
    // Still the same start on the same machine, after the wait: another opened meanwhile is not this one.
    bool same() => mounted && starting.project?.name == project && on != null && identical(starting.openedOn, on);
    try {
      progress = await connections.progress(host);
    } on OrganizationRefused catch (refused) {
      if (!same()) return;
      return offerOnly(
        starting.project!.workRepositories.toSet(),
        '$host could not be asked which repositories it has taken, so every one is offered: ${refused.words}',
      );
    }
    final rows = progress.of(project)?.repositories ?? const [];
    if (!same() || rows.isEmpty) return;
    final work = starting.project!.workRepositories.toSet();
    final byState = <String, int>{};
    for (final row in rows) {
      if (row.state != 'taken' && work.contains(row.repository)) byState[row.state] = (byState[row.state] ?? 0) + 1;
    }
    String count(int n) => n == 1 ? '1 repository' : '$n repositories';
    offerOnly(
      {
        for (final row in rows)
          if (row.state == 'taken') row.repository,
      },
      byState.isEmpty
          ? null
          : [
              for (final MapEntry(key: state, value: n) in byState.entries)
                switch (state) {
                  'no-central' =>
                    '${count(n)} ${n == 1 ? 'names' : 'name'} no central address, so $host has not taken '
                        '${n == 1 ? 'it' : 'them'}.',
                  'waiting' => '${count(n)} ${n == 1 ? 'is' : 'are'} still to be taken by $host.',
                  _ => '${count(n)}: $state on $host.',
                },
            ].join(' '),
    );
  }

  /// Continues a finished unattended run, with what it was asked to do last time in the box.
  Future<void> _continueTheWork([Task? work]) async {
    final task = work ?? _fleet.selectedTask;
    final project = (task == null ? null : _projectOf(task))?.project ?? _fleet.selectedProject?.project;
    if (task == null || project == null) return;
    unawaited(widget.starting.continueFrom(_fleet.backend, project, task));
    await _offerToStart();
  }

  /// The machine the start form was opened on, found by the backend it asks: never the one chosen since. Null where
  /// it is no longer watched.
  Machine? get _startMachine {
    final on = widget.starting.openedOn;
    if (on == null) return null;
    // The one acted on first: it is the one a form opened just now was opened on.
    final current = widget.machines.current;
    if (identical(widget.machines.of(current).backend, on)) return current;
    return widget.machines.all.where((each) => identical(widget.machines.of(each).backend, on)).firstOrNull;
  }

  Future<void> _offerToStart({VoidCallback? onChangeProject}) async {
    // Every step around the start takes the machine the form was opened on, whichever is chosen meanwhile.
    // A form whose machine is gone starts nothing, rather than on the machine chosen meanwhile.
    final machine = widget.starting.openedOn == null ? widget.machines.current : _startMachine;
    if (machine == null) {
      widget.starting.close();
      return;
    }
    final vault = _toolsFor(machine).vault;
    final signIn = _signInOn(widget.starting.signIn, machine);
    await openStartWork(
      context,
      starting: widget.starting,
      onChangeProject: onChangeProject,
      onStart: () => _beginTheRun(machine),
      onKeep: _keepAsTemplate,
      onStoreTheCredential: onTheMachineAsWritten(machine, 'porelo') == null
          ? null
          : () => _storeTheCredentialToStart(machine),
      onImportTheSignIn: onTheMachineAsWritten(machine, 'porelo') == null
          ? null
          : () => _importTheSignInToStart(machine),
      onLogIn: onTheMachineAsWritten(machine, 'porelo') == null ? null : (agent) => _logInWithTheAgent(agent, machine),
      onOpenWithThisDevice: vault.devices.enrolledHere ? () => _openWithThisDeviceToStart(machine) : null,
      onGrant: (entry) => _grantToStart(entry, machine),
      onFixInATerminal: onTheMachine(machine, _aShell, terminal: true) == null
          ? null
          : () => _fixTheUpstreamToStart(machine),
    );
    // Left however it was left: only the wait is dropped, and the sign-in goes on on the machine, which is said.
    final left = signIn.leave();
    signIn.attachHere = null;
    if (left != null && widget.machines.all.contains(machine)) widget.machines.of(machine).say(left);
    widget.starting.close();
  }

  /// Puts [signIn] on [machine]: its name for the sentences, whether the person reaches it from another one, and
  /// a terminal attached to its login **on that machine**, never here for a machine reached from elsewhere.
  SigningIn _signInOn(SigningIn signIn, Machine machine) => signIn
    ..machine = machine.name
    ..remote = machine.needsATunnel || (!machine.isThisComputer && machine.relay?.kind != 'wsl')
    ..cannotAttach = onTheMachine(machine, const <String>['porelo'], terminal: true) == null
        ? '${machine.name} is reached through a socket this window does not raise, so no terminal opens there '
              'from here; sign in at the machine with porelo vault login'
        : null
    ..attachHere = (attach) => _attachToTheSignIn(attach, machine, signIn);

  /// Runs [attach], as the machine named it, on [machine] in a terminal, while [signIn] says its login runs there:
  /// the person follows the link and pastes the code there, never into this program. **Closing it leaves the
  /// terminal only**; what waits on the sign-in goes on waiting.
  Future<void> _attachToTheSignIn(List<String> attach, Machine machine, SigningIn signIn) async {
    if (!mounted || !widget.machines.all.contains(machine) || !signIn.running) return;
    final command = onTheMachine(machine, attach, terminal: true);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Sign in to ${signIn.who} on ${machine.name}',
      explanation:
          'Follow the link the terminal shows, sign in in your browser, and paste the code it gives you here, in the '
          'terminal. It goes straight to the machine and never through this program.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
      stillWorking:
          'The sign-in runs on ${machine.name}. The first one builds its image, which takes a few minutes and may '
          'print nothing for a while.',
      cancel: 'Close the terminal',
    );
  }

  /// Leaves the waits on sign-ins of a machine no longer watched: their connections close, and the sign-ins go on
  /// on the machine.
  void _leaveTheSignInsOfForgottenMachines() {
    bool forgotten(SigningIn signIn) {
      final on = signIn.on;
      return on != null && !widget.machines.all.any((each) => identical(widget.machines.of(each).backend, on));
    }

    for (final signIn in <SigningIn>[
      widget.starting.signIn,
      _startingAgents.signing,
      ..._signInsAfterAFailedStart.values,
    ]) {
      // Whatever is still out is left too, a start or a question among them: its late answer opens nothing.
      if (forgotten(signIn) && (signIn.out || signIn.running)) signIn.leave();
    }
  }

  /// A login shell on the machine, for a person to run what the machine named.
  static const List<String> _aShell = <String>['bash', '-l'];

  /// Whether the start form is still open on [machine] after a wait: the window there, the machine still watched,
  /// and the form neither closed nor opened on another machine since.
  bool _formStillOn(Machine machine) =>
      mounted &&
      widget.machines.all.contains(machine) &&
      widget.starting.project != null &&
      identical(widget.starting.openedOn, widget.machines.of(machine).backend);

  /// Opens a shell on the machine whose upstream refused its key, where the person runs the command
  /// the machine named, then asks the machine again whether work can start: the fix is its to see.
  Future<void> _fixTheUpstreamToStart(Machine machine) async {
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
    if (!_formStillOn(machine)) return;
    await widget.starting.askAgain();
  }

  /// Grants what starting said needs a grant, in a browser, then asks the machine again whether work
  /// can start: the grant is the machine's to confirm.
  Future<void> _grantToStart(String entry, Machine machine) async {
    if (!widget.machines.all.contains(machine)) return;
    await showGranting(context, Granting(widget.machines.of(machine).backend, machine, entry));
    if (!_formStillOn(machine)) return;
    await widget.starting.askAgain();
  }

  /// Opens the locked vault starting was refused on, with this device and for as long as the person
  /// chooses — then asks the machine again whether work can start.
  Future<void> _openWithThisDeviceToStart(Machine machine) async {
    if (!widget.machines.all.contains(machine)) return;
    await _actOnTheVault(VaultAct.open, on: machine);
    if (!_formStillOn(machine)) return;
    await widget.starting.askAgain();
  }

  /// Copies the sign-in the machine found into its vault, by the machine's own command, in a terminal there
  /// (the same sign-in terminal, since a shut vault asks there), then asks again whether work can start.
  Future<void> _importTheSignInToStart(Machine machine) async {
    final readiness = widget.starting.readiness;
    final command = readiness == null ? null : onTheMachine(machine, readiness.importCommand, terminal: true);
    if (command == null) return;
    await runInATerminal(
      context,
      title: 'Use the sign-in found on the machine',
      explanation:
          'The machine copies what the agent already holds into its vault. It stays on the machine and never '
          'goes through this program.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!_formStillOn(machine)) return;
    await widget.starting.askAgain();
  }

  /// Stores the credential starting said is missing, by the line the machine names for its
  /// provider, in a terminal there — then asks the machine again whether work can start.
  Future<void> _storeTheCredentialToStart(Machine machine) async {
    final readiness = widget.starting.readiness;
    if (readiness == null || !widget.machines.all.contains(machine)) return;
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
      if (!_formStillOn(machine)) return;
      await widget.starting.askAgain();
      return;
    }
    // A Porelo older than the field: the provider's line, run as the machine wrote it.
    final Providers providers;
    try {
      providers = await widget.machines.of(machine).backend.providers();
    } on Exception catch (ex) {
      // Pressed from a dialog nobody awaits: said here, or it reaches nobody.
      if (!mounted || !widget.machines.all.contains(machine)) return;
      widget.machines
          .of(machine)
          .say('The machine could not say how to store a credential for ${readiness.provider}: $ex');
      return;
    }
    final provider = providers.providers.where((each) => each.name == readiness.provider).firstOrNull;
    final command = provider == null ? null : onTheMachineAsWritten(machine, provider.storeCommand);
    // No terminal for a form closed, or opened on another machine, while the machine answered.
    if (!mounted || !_formStillOn(machine)) return;
    if (command == null) {
      widget.machines.of(machine).say('${machine.name} names no way to store a credential for ${readiness.provider}.');
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
    if (!_formStillOn(machine)) return;
    await widget.starting.askAgain();
  }

  /// Runs [agent]'s own login on the machine, through Porelo, in a terminal there: its page is offered
  /// as a link to open here, and its reply to `localhost` is forwarded while the terminal is open.
  /// Then asks the machine again whether work can start.
  Future<void> _logInWithTheAgent(Agent agent, Machine machine) => _logIn(
    agent,
    on: machine,
    askAgain: widget.starting.askAgain,
    stillMissing: () => widget.starting.needsASignIn,
    stillOpen: () => _formStillOn(machine),
    from: 'the start form',
  );

  /// Opens the wizard that starts the agent each repository of [name] names, on the machine acted on.
  ///
  /// **On the machine it was chosen on**, taken at the press: another chosen while that one is read changes nothing.
  Future<void> _startTheAgents(String name) async {
    final machine = widget.machines.current;
    final fleet = _fleet;
    bool stillThere() => mounted && widget.machines.all.contains(machine);
    await fleet.refresh(quietly: true);
    if (!stillThere()) return;
    final why = await _takeIfCarried(name, on: fleet);
    if (!stillThere()) return;
    if (why != null) return fleet.say(why);
    final project = _listed(name, on: fleet);
    if (project == null || !mounted) return;
    // A row's agent comes with its file, so this is the first it can be said for a project just taken.
    if (StartAgents.whyNot(project) case final lacking?) return fleet.say(lacking);
    final starting = _startingAgents;
    _signInOn(starting.signing, machine);
    unawaited(starting.open(fleet.backend, project));
    await openStartAgents(
      context,
      starting: starting,
      onLogIn: onTheMachineAsWritten(machine, 'porelo') == null
          ? null
          : (agent) => _logIn(
              agent,
              on: machine,
              stillOpen: () => mounted && widget.machines.all.contains(machine) && starting.project != null,
              askAgain: starting.askAgain,
              stillMissing: () => starting.signInsNeeded.any((each) => each.name == agent.name),
              from: 'the wizard',
            ),
    );
    // Closed however it was left: nothing more starts, and a sign-in that runs goes on on the machine, which is said.
    starting.signing.attachHere = null;
    final left = starting.left;
    starting.left = null;
    if (left != null && widget.machines.all.contains(machine)) widget.machines.of(machine).say(left);
  }

  /// Runs [agent]'s own login on the machine, then asks again through [askAgain] whether work can
  /// start; [stillMissing] says whether it still has nothing to sign in with, and [from] where to try again.
  Future<void> _logIn(
    Agent agent, {
    Machine? on,
    required Future<void> Function() askAgain,
    required bool Function() stillMissing,
    required bool Function() stillOpen,
    required String from,
  }) async {
    final machine = on ?? widget.machines.current;
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
      explanation: signInExplanation(agent, machine.name),
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
        // Asked only of the form or wizard still open on this machine.
        if (stillOpen()) await askAgain();
        final label = agent.label.isEmpty ? agent.name : agent.label;
        return stillMissing()
            ? 'Nothing was stored for $label on ${machine.name}. What the terminal printed says why; '
                  'sign in again from $from.'
            : 'Signed in to $label: the credential is stored on ${machine.name}. You can close this.';
      },
    );
    if (!stillOpen()) return;
    await askAgain();
  }

  /// Keeps what is on screen as a recurring job.
  void _keepAsTemplate() {
    final job = widget.starting.asTemplate;
    if (job == null) return;
    unawaited(widget.templates.keep(job));
  }

  /// Runs it, on the machine its form was opened on, and hands the stream to the session record rather than to
  /// this view.
  void _beginTheRun(Machine machine) {
    // Taken at the press: the form closes with it, and a question before the start is answered after.
    final pressed = widget.starting.press();
    if (pressed == null) return;
    unawaited(_beginAfterTheProposal(machine, pressed));
  }

  /// Before the first task on a repository in default with no checkout here, the machine's proposal is put first.
  Future<void> _beginAfterTheProposal(Machine machine, StartPress pressed) async {
    final repository = pressed.repository;
    if (pressed.project == defaultProject && repository != null && !pressed.fromACheckout) {
      final AfterTheProposal after;
      try {
        after = await askBeforeTheFirstTask(
          pressed.on,
          repository,
          (first) => mounted && widget.machines.all.contains(machine)
              ? askFirstStart(context, first: first, repository: repository)
              : Future<bool?>.value(),
          stillWanted: () => mounted && widget.machines.all.contains(machine),
        );
      } on VarlinkException catch (refusal) {
        if (!mounted || !widget.machines.all.contains(machine)) return;
        widget.machines
            .of(machine)
            .say(
              '${machine.name} could not say what a first task on $repository is to do, so nothing '
              'started: ${refusal.parameters['message'] ?? refusal.parameters['detail'] ?? refusal.simpleName}',
            );
        return;
      }
      if (after == AfterTheProposal.startNothing || !mounted) return;
    }
    _run(machine, pressed);
  }

  void _run(Machine machine, StartPress pressed) {
    // The machine may have been forgotten while the question before the start was out: nothing is sent then.
    if (!widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    final project = pressed.project;
    final named = pressed.named;
    // Somebody who chose to work by hand is taken into the work once it is up, not left at a log.
    final byHand = pressed.mode == Mode.shell || pressed.mode == Mode.agent;
    final runningBefore = <String>{
      for (final task in fleet.tasks)
        if (task.project == project && task.running) task.name,
    };
    final operation = widget.operations.run(title: pressed.title, machine: machine.name, output: pressed.send());
    if (pressed.mode == Mode.unattended) {
      _runs[operation.id] = UnattendedRun(
        machine: machine,
        fleet: fleet,
        project: project,
        named: named,
        operation: operation,
        operations: widget.operations,
      );
    }
    widget.shell.openOperation(operation.id);
    if (byHand) unawaited(_workInItOnceUp(machine, operation, project, named, runningBefore));
    final agent = pressed.agent;
    if (pressed.signsIn && agent != null) unawaited(_offerASignInIfItFails(machine, pressed.on, operation, agent));
  }

  /// Once a start on [machine] has failed, asks that machine whether [agent] is signed in there, and where it is not
  /// offers the sign-in on the operation: a start refused for a sign-in gone missing meanwhile is **that start's
  /// failure, never retried**.
  Future<void> _offerASignInIfItFails(Machine machine, FleetBackend on, Operation operation, String agent) async {
    final ended = Completer<void>();
    void check() {
      if (!operation.running && !ended.isCompleted) ended.complete();
    }

    _waitsForAFailedStart[operation.id] = check;
    widget.operations.addListener(check);
    check();
    await ended.future;
    if (!mounted) return;
    widget.operations.removeListener(check);
    _waitsForAFailedStart.remove(operation.id);
    if (!operation.failed || !widget.machines.all.contains(machine)) return;
    final signIn = _signInOn(SigningIn(), machine);
    await signIn.ask(on, agent: agent);
    if (!mounted || !widget.machines.all.contains(machine) || signIn.signedIn || signIn.served != true) {
      signIn.leave();
      signIn.dispose();
      return;
    }
    // Its view closed while the machine was asked: a sign-in found running there is not waited on.
    final open = switch (widget.shell.opened) {
      OperationOpened(:final id) => id,
      _ => null,
    };
    if (open != operation.id) signIn.leave();
    setState(() => _signInsAfterAFailedStart[operation.id] = signIn);
  }

  /// Opens the session on the work a start brought up on [machine], once the start has finished well: the one of
  /// the name it was given, or else the one of that project that was not running before.
  Future<void> _workInItOnceUp(
    Machine machine,
    Operation operation,
    String project,
    String named,
    Set<String> runningBefore,
  ) async {
    final ended = Completer<void>();
    void check() {
      if (!operation.running && !ended.isCompleted) ended.complete();
    }

    widget.operations.addListener(check);
    check();
    await ended.future;
    widget.operations.removeListener(check);
    if (!mounted || operation.failed || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    await fleet.refresh(quietly: true);
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final up = fleet.tasks.where((task) => task.project == project && task.running).toList();
    final task =
        (named.isEmpty ? null : up.where((each) => each.task == named).firstOrNull) ??
        up.where((each) => !runningBefore.contains(each.name)).firstOrNull;
    if (task == null) return;
    // The start's own terminal may have ended with it, and a look would then say none is open: the
    // person came to meet the agent, so a new one opens, as *Open a new terminal* does.
    if (Sessions.whyNot(task, machine) == null) {
      // On the new task's tab before the session open now is left, so leaving it opens nothing again where it was.
      _workView.showNewTerminal(machine.name, task);
      await widget.sessions.leave();
      if (!mounted || !widget.machines.all.contains(machine)) return;
    }
    _openSession(task, on: machine);
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
    final path = await widget.pickAFile(title: 'A file to hand to ${task.shown}');
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
      said = '${task.shown} was not brought up to its source: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (lost) {
      said = 'Lost contact with the machine: ${lost.message}';
    } on FeatureNotSupported catch (older) {
      said = '$older';
    }
    if (mounted) _fleet.say(said);
  }

  /// Certifies a task for another week, by the command line, which asks this computer's agent.
  Future<void> _certifyAgain(Task task) async {
    final machine = widget.machines.current;
    // Its machine's, whichever is selected when the command has answered.
    final fleet = _fleet;
    if (machine.needsATunnel && task.project.isEmpty) {
      fleet.say('${task.name} names no project, so nothing here can certify it on ${machine.name}.');
      return;
    }
    final arguments = certifyAgainArguments(
      task,
      host: machine.needsATunnel ? machine.host : '',
      project: task.project,
    );
    String said;
    try {
      final ran = await certifyAgainRunner('porelo', arguments);
      final why = '${ran.err}\n${ran.out}'.trim();
      said = ran.code == 0
          ? '${task.shown} is certified for another week.'
          : '${task.shown} was not certified: ${why.isEmpty ? 'porelo ended with ${ran.code}' : why}';
    } on ProcessException {
      said = "Porelo's command line could not be started here, so ${task.shown} was not certified.";
    } on WorkspaceRefused catch (refused) {
      said = refused.words;
    }
    if (!mounted) return;
    // Read first, and quietly: a refresh's own line would replace what was said here.
    try {
      await fleet.refresh(quietly: true);
    } on VarlinkException {
      // What the machine said of the certificate still stands; the next reading says what it says then.
    } on FeatureNotSupported {
      // The same.
    }
    if (!mounted) return;
    fleet.say(said);
  }

  /// Takes back a file the work was handed, chosen from what it holds.
  Future<void> _takeBackFrom(Task task) async {
    final files = task.files ?? const <HandedFile>[];
    final name = await showDialog<String>(
      context: context,
      builder: (asked) => SimpleDialog(
        title: Text('Take a file back from ${task.shown}'),
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
      title: 'Write to the agent of ${task.shown}',
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
      _fleet.say('Written into the inbox of ${task.shown}. Its agent reads it there.');
    } on VarlinkException catch (refusal) {
      _fleet.say(
        refusal.simpleName == 'NoSuchTask'
            ? '${task.shown} is not on this machine any more, so nothing was written.'
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
  Future<void> _look(PendingPush push, {Machine? on}) async {
    final fleet = widget.machines.of(on ?? widget.machines.current);
    widget.shell.openReview();
    await widget.gate.look(fleet.backend, push);
  }

  /// Forwards the push being judged, onto a branch somebody names.
  Future<void> _approve({Machine? on}) async {
    final owner = on ?? widget.machines.current;
    final fleet = widget.machines.of(owner);
    final push = widget.gate.looking;
    if (push == null) return;
    final machine = owner.name;
    final project = widget.gate.project?.name;
    if (project == null) return;
    final taskBranch =
        fleet.tasks
            .where(
              (task) =>
                  task.project == project &&
                  (task.repository == push.repository || widget.gate.project?.repositoryOf(task) == push.repository) &&
                  task.task == push.name &&
                  task.forgeBranch.isNotEmpty,
            )
            .firstOrNull
            ?.forgeBranch ??
        '';
    final lastBranch = widget.settings.lastForwardedBranch(machine, project, push.repository, push.name);
    final initialBranch = taskBranch.isNotEmpty ? taskBranch : lastBranch ?? '';
    // The forge may answer late; by then another push, project or machine may be shown.
    bool stillJudging() =>
        mounted &&
        (_machinePlaceOwner ?? widget.machines.current) == owner &&
        widget.machines.all.contains(owner) &&
        identical(widget.gate.looking, push) &&
        widget.gate.project?.name == project;
    final offered = await _branchesFor(push);
    if (!mounted || !stillJudging()) return;
    final branch = await askWhichBranch(
      context,
      subject: push.subject,
      toOrigin: widget.gate.project?.name == defaultProject,
      branches: offered?.branches ?? const <String>[],
      defaultBranch: offered?.defaultBranch,
      upstream: _upstreamFor(push) ?? '',
      initialBranch: initialBranch,
      branchSource: taskBranch.isNotEmpty
          ? "this task's branch"
          : initialBranch.isNotEmpty
          ? 'last used for this task'
          : '',
    );
    if (branch == null || !stillJudging()) return;
    final answer = await widget.gate.approve(fleet.backend, branch);
    if (answer.forwarded) await _rememberForward(machine, project, push, branch);
    if (!mounted) return;
    _afterAForward(answer.said, on: owner);
  }

  /// Keeps the branch a confirmed forward went to; a settings file that cannot be written loses only the prefill.
  Future<void> _rememberForward(String machine, String project, PendingPush push, String branch) async {
    try {
      await widget.settings.rememberForwardedBranch(machine, project, push.repository, push.name, branch);
    } on Exception catch (error) {
      _fleet.say('The branch could not be kept for the next forward: $error');
    }
  }

  /// Says what came of a forward and goes back to the gate, unless it was refused: a refused key's way
  /// through stays in the review.
  void _afterAForward(String said, {Machine? on}) {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final fleet = widget.machines.of(machine);
    if (said.isNotEmpty) fleet.say(said);
    // Repositories that could not be read are said in the gate's list, not a reason to stay on a review gone.
    if (widget.gate.otherProblem == null && widget.gate.keyRefused == null) widget.shell.openGate();
    // What waits is read again at once: the project's badge said "1" after the push was through
    // (walk 8).
    unawaited(fleet.refresh(quietly: true));
  }

  /// Keeps [key] for the refused forward's address, then forwards again onto the same branch.
  Future<void> _keepKey(SshKey key, {Machine? on}) async {
    final owner = on ?? widget.machines.current;
    final fleet = widget.machines.of(owner);
    final push = widget.gate.looking;
    final project = widget.gate.project?.name;
    final branch = widget.gate.keyRefused?.branch;
    final machine = owner.name;
    final answer = await widget.gate.keepKey(fleet.backend, key);
    if (answer.forwarded && push != null && project != null && branch != null) {
      await _rememberForward(machine, project, push, branch);
    }
    if (!mounted) return;
    _afterAForward(answer.said, on: owner);
  }

  /// Opens a terminal on the machine with what the refusal names to run, shown first and started only
  /// when the person says so; then reads the keys again.
  Future<void> _refusedKeyInATerminal({Machine? on}) async {
    final refused = widget.gate.keyRefused?.refused;
    final machine = on ?? widget.machines.current;
    final fleet = widget.machines.of(machine);
    if (refused == null || refused.command.isEmpty) return;
    final command = onTheMachine(machine, refused.command, terminal: true);
    if (command == null) {
      fleet.say('${machine.name} is not a machine a terminal is opened on from here.');
      return;
    }
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('A terminal on ${machine.name}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('This runs on the machine, in a terminal here, once you start it:'),
                const SizedBox(height: Space.small),
                SelectableText(
                  refused.command.join(' '),
                  key: const Key('refused-key-command'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          FilledButton(
            key: const Key('refused-key-start'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start it'),
          ),
        ],
      ),
    );
    if (start != true || !mounted) return;
    await runInATerminal(
      context,
      title: 'On ${machine.name}',
      explanation: 'It runs on the machine. Nothing it shows goes through this program.',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
    );
    if (!mounted || !widget.machines.all.contains(machine)) return;
    await widget.gate.readKeys(fleet.backend);
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

  /// The upstream the machine names for the repository holding the push.
  String? _upstreamFor(PendingPush push) =>
      widget.gate.project?.repositoryStates.where((each) => each.name == push.repository).firstOrNull?.upstream;

  /// The branches and default reported by a reachable forge, or null when none answers.
  Future<({List<String> branches, String defaultBranch})?> _branchesFor(PendingPush push) async {
    final upstream = _upstreamFor(push);
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
  Future<void> _reject({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    final fleet = widget.machines.of(machine);
    final reason = await askForWords(
      context,
      title: 'Drop the request',
      explain:
          'The work stays in the mirror; only the request is gone. The task it came from is told '
          'in its inbox, with your words when you give them, so its agent knows why.',
      label: 'Why, for its agent (optional)',
      confirm: 'Drop it',
    );
    if (reason == null || !mounted || !widget.machines.all.contains(machine)) return;
    final said = await widget.gate.reject(fleet.backend, reason: reason);
    if (said.isNotEmpty) fleet.say(said);
    if (widget.gate.otherProblem == null) widget.shell.openGate();
    // What waits is read again at once: the project's badge said "1" after the push was through
    // (walk 8).
    unawaited(fleet.refresh(quietly: true));
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
    widget.shell.openMachine(machine);
    await _showConnections();
  }

  /// Starts Porelo where it is not answering, then checks the machine once it answers.
  Future<void> _startThenCheck({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!await _startTheDaemon(on: machine)) return;
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
        if (mounted && widget.machines.current == machine) unawaited(_checkFirstTime(machine));
      });
    };
    widget.machines.addListener(look);
    fleet.addListener(look);
    look();
  }

  /// Asks [machine] what it can run, and takes the page only where it has something to say: a person
  /// who came to it for a row of work goes on to that row. It stays one action away otherwise.
  Future<void> _checkFirstTime(Machine machine) async {
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final tools = _toolsFor(machine);
    final readiness = tools.readiness;
    final fleet = widget.machines.of(machine);
    await tools.run(() => readiness.look(fleet.backend));
    if (_stillWatching(machine, tools) && widget.machines.current == machine && readiness.ready != true) {
      _goToMachineSection(MachineSection.health);
    }
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
    if (mounted && widget.machines.all.contains(machine)) await _checkTheMachine(on: machine);
  }

  /// Offers to start a daemon on a machine that is not answering, and starts it on a yes; answers
  /// whether it was asked to.
  ///
  /// The one thing a silent machine can still be asked. What runs is named before it runs: this
  /// is the interface reaching further into somebody else's machine than forwarding a socket goes,
  /// and it goes no further than a line somebody read and agreed to.
  Future<bool> _startTheDaemon({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return false;
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
    await widget.machines.raiseAgainIfNeeded(machine, asked: true);
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
  Future<void> _stopTheDaemon({Machine? on}) async {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
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
    widget.logs.open(tile.fleet.backend, task.name, taskLog, formatted: true);
    widget.shell.openLog(task.name, taskLog, formatted: true);
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
    final agreed = await confirmRemove(context, task: task.shown, running: task.running);
    if (!agreed) return;
    await _fleet.removeEvenIfRunning(task.name);
  }

  /// Takes a piece of work down and starts it again from scratch. **Nothing is started after a
  /// refused removal** — that would lose the reason.
  Future<void> _recreate(Task task) async {
    // The machine the task is on, whichever is chosen while it is confirmed or cleared.
    final machine = widget.machines.current;
    final fleet = _fleet;
    final agreed = await confirmRecreate(context, task: task.shown, helpers: task.helpers);
    if (!agreed || !mounted || !widget.machines.all.contains(machine)) return;
    final clear = await fleet.clearTheWayToRecreate(task.name);
    if (!clear || !mounted || !widget.machines.all.contains(machine)) return;

    final project = fleet.projects
        .where((each) => each.name == task.project)
        .map((each) => each.project.name)
        .firstOrNull;
    final operation = widget.operations.run(
      title: 'Recreate ${task.shown}',
      machine: machine.name,
      // The same name and the same agent, mode, prompt and model: recreating changes the environment.
      output: fleet.backend.startTask(
        task: task.task,
        project: project,
        agent: task.agent.isEmpty ? null : task.agent,
        mode: task.mode.recognized ? task.mode : null,
        prompt: task.prompt.isEmpty ? null : task.prompt,
        model: task.model?.isEmpty ?? true ? null : task.model,
        repository: fleet.projectOf(task)?.repositoryOf(task),
      ),
    );
    widget.shell.openOperation(operation.id);
  }

  /// Finds a command and opens its home.
  Future<void> _openFinder() async {
    final machine = _machinePlaceOwner ?? widget.machines.current;
    final chosen = await showCommandFinder(context, _commands());
    if (chosen == null || !mounted) return;
    // Something with no single place on screen runs at once; everything else is shown where it
    // lives, so the next time it is found there.
    if (chosen.home == Home.none || chosen.home == Home.appBar || chosen.home == Home.openedView) {
      chosen.run();
    } else {
      if ({Home.machineTitle, Home.machineMenu, Home.statusLine}.contains(chosen.home)) {
        widget.shell.openMachine(machine);
        widget.shell.showOnItem(chosen.id);
        return;
      }
      if (chosen.home == Home.organizationRow && _organization?.view != null) {
        widget.shell.choosePlace(ShellPlace(Section.organization, organization: _organization!.view!.name));
        if (!widget.shell.foldedOpen.contains(widget.shell.place.key)) {
          widget.shell.toggleFold(widget.shell.place.key);
        }
        widget.shell.showOnItem(chosen.id);
        return;
      }
      if (chosen.home == Home.machineRow) {
        final run = _hostRuns.preparing
            .where((run) => chosen.group == run.name || chosen.group == '${run.project} server')
            .firstOrNull;
        if (run != null) {
          widget.shell.openMachine(Machine(name: run.name, socketPath: ''));
          widget.shell.showOnItem(chosen.id);
          return;
        }
        widget.shell.openMachine(machine);
        widget.shell.showOnItem(chosen.id);
        return;
      }
      if (chosen.home == Home.organizationRow) {
        widget.shell.choosePlace(const ShellPlace(Section.organizations));
        widget.shell.showOnItem(chosen.id);
        return;
      }
      // Where it lives: a piece of work's tile is under Work, a project's menu on its page, setting
      // one up on Projects, and the rest on the machine's page.
      widget.shell.show(
        chosen.id,
        section: switch (chosen.home) {
          Home.tileMenu => Section.work,
          Home.projectMenu || Home.repositoryRow || Home.startTile || Home.templateTile => Section.project,
          Home.attentionRow => Section.attention,
          Home.machineRow => Section.machines,
          Home.forgeRow => Section.forges,
          Home.organizationRow => Section.organization,
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
              if (intent.id == 'detail.close' && (_scaffold.currentState?.isDrawerOpen ?? false)) {
                _leaveDrawer();
                return null;
              }
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
            onDrawerChanged: (open) {
              if (open) widget.shell.revealPlace();
              if (!open) _menuFocus.requestFocus();
            },
            // Behind the menu button when the window is narrow: the work gets the width.
            drawer: size.showsTreeBeside
                ? null
                : Drawer(
                    width: WindowSize.drawerWidth(context),
                    child: SafeArea(child: _rail(WindowSize.drawerWidth(context))),
                  ),
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  if (widget.newerVersion.arrived) NewerVersionBanner(onRestart: () => SystemNavigator.pop()),
                  Expanded(
                    // Stretched, so a page shorter than the window starts under the title bar, never centred.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (size.showsTreeBeside) ...<Widget>[
                          _rail(Sizes.tree),
                          const VerticalDivider(width: Sizes.divider),
                        ],
                        Expanded(
                          child: switch (widget.shell.section) {
                            Section.work => _workArea(),
                            Section.attention => _needsYou(),
                            Section.cards => _cardsPage(),
                            Section.organizations => _organizationsFacts(),
                            Section.machines =>
                              _organizationHost == null || _organization == null
                                  ? _machinesFacts()
                                  : _machineOnePage(_organizationHost!),
                            Section.projects => _projectsPage(),
                            Section.forges => _forgesPage(),
                            Section.organization =>
                              widget.shell.place.organizationSection == null
                                  ? _organizationsFacts(one: true)
                                  : _organizationPage(),
                            Section.forge => _forgePage(),
                            Section.machine || Section.project => ListenableBuilder(
                              listenable: _hostRuns,
                              builder: (context, _) => widget.shell.section == Section.project
                                  ? _machineArea()
                                  : switch (widget.shell.place.machineSection) {
                                      null => _machineFacts(),
                                      final MachineSection section => _machineSection(section),
                                    },
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

  final _menuFocus = FocusNode(debugLabel: 'Open navigation menu');

  Widget _organizationButton(WindowSize size) {
    final name = _organization?.view?.name ?? 'No organization';
    final command = organizationAddressCommands(context, _organization).first;
    return Tooltip(
      message: command.unavailable == null ? name : '$name — ${command.unavailable}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.organizationButtonWidth),
        child: TextButton(
          key: const Key('organization-choice'),
          onPressed: command.available ? command.run : null,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _barOverflow(List<Command> commands) => PopupMenuButton<String>(
    key: const Key('bar-overflow'),
    tooltip: 'More actions',
    onSelected: (id) {
      if (id == 'finder') {
        unawaited(_openFinder());
        return;
      }
      if (id == 'machines.add') {
        _addAMachine();
        return;
      }
      if (id == 'about') {
        _showAbout();
        return;
      }
      if (id == 'walk') {
        widget.walk?.show();
        return;
      }
      if (id == 'options') {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Options'),
              children: [
                for (final command in commands)
                  if (command.home == Home.appBar && command.group == 'Options')
                    SimpleDialogOption(
                      key: Key(command.id),
                      onPressed: command.available
                          ? () {
                              Navigator.pop(context);
                              command.run();
                            }
                          : null,
                      child: Text(command.label),
                    ),
              ],
            ),
          ),
        );
        return;
      }
      final command = commands.where((command) => command.id == id && command.available).firstOrNull;
      command?.run();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'finder', child: Text('Find a command (Ctrl+K)')),
      const PopupMenuItem(value: 'machines.add', child: Text('Watch another machine…')),
      for (final command in commands)
        if (command.home == Home.appBar && command.group == 'Machines' && command.id != 'machines.add')
          PopupMenuItem(
            value: command.id,
            enabled: command.available,
            child: Text(command.unavailable == null ? command.label : '${command.label} — ${command.unavailable}'),
          ),
      const PopupMenuItem(value: 'options', child: Text('Options')),
      if (widget.walk?.hidden ?? false) const PopupMenuItem(value: 'walk', child: Text('Show the guided walk')),
      const PopupMenuItem(value: 'about', child: Text('About Porelo')),
    ],
  );

  Widget _cardsPage() => Center(
    child: FilledButton(
      onPressed: () => unawaited(showIdentity(context, model: widget.identity)),
      child: const Text('My key and card…'),
    ),
  );

  void _chooseTreePlace(ShellPlace place, bool branch, {bool selectMachine = true}) {
    if (place.machineSection != null &&
        place.machine != null &&
        (!widget.machines.all.contains(place.machine) ||
            _hostRuns.preparing.any((run) => run.name == place.machine!.name))) {
      place = ShellPlace(Section.machine, machine: place.machine);
    }
    if (!branch) _leaveDrawer();
    setState(() {
      _organizationProject = null;
      _organizationHost = null;
      _organizationHostFrom = null;
      _organizationProjectFrom = null;
      _machineProjects = false;
      _projectFrom = null;
    });
    final machine = place.machine;
    if (selectMachine && machine != null && widget.machines.all.contains(machine)) widget.machines.select(machine);
    widget.shell.choosePlace(place, branch: branch);
    if (place.section == Section.work) _workView.search.clear();
    if (place.section == Section.cards) unawaited(showIdentity(context, model: widget.identity));
  }

  void _goToMachineSection(MachineSection section, {Machine? on}) {
    final machine = on ?? widget.machines.current;
    if (!mounted || !widget.machines.all.contains(machine)) return;
    final place = ShellPlace(Section.machine, machine: machine, machineSection: section);
    if (widget.shell.place.key == place.key) {
      unawaited(_readMachineSection(machine, section));
    } else {
      _chooseTreePlace(place, false, selectMachine: on == null);
    }
  }

  /// Whether [machine] is one an organization's card names, so its managing is its Machine Admins' list.
  bool _hasMachineAdmins(Machine machine) =>
      _onTheOrganizationsPage(machine) &&
      (_organization?.view?.hosts.any((host) => host.name == machine.hostCard!.name) ?? false);

  /// Whether [machine]'s page is its organization's page of it, as a machine an organization's card names is.
  bool _onTheOrganizationsPage(Machine machine) => machine.hostCard != null && _organization != null;

  /// The way back from one of [machine]'s sections: its machines, then the machine.
  List<LeafPathStep> _machineSectionPath(Machine machine) => [
    (label: 'My machines', go: () => _chooseTreePlace(const ShellPlace(Section.machines), true)),
    (label: machine.name, go: () => widget.shell.openMachine(machine)),
  ];

  Widget _machineSection(MachineSection section) {
    final machine = widget.shell.place.machine!;
    if (!widget.machines.all.contains(machine)) return _machineFacts();
    final fleet = widget.machines.of(machine);
    final tools = _toolsFor(machine);
    return ListenableBuilder(
      listenable: Listenable.merge([
        fleet,
        tools.vault,
        tools.vault.devices,
        tools.connections,
        tools.inventory,
        tools.authentication,
        tools.readiness,
      ]),
      builder: (context, _) {
        final answering = fleet.reachability == Reachability.connected;
        final readAgo = howLongSince(
          _sectionReadAt[ShellPlace(Section.machine, machine: machine, machineSection: section).key],
        );
        final opened = _opened(on: machine);
        final notices = <Widget>[
          if (!answering) ...[
            Text('${machine.name} does not answer.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Text(readAgo == null ? 'The read time of these rows is not known.' : 'Read $readAgo ago; last known rows.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('machine-section-retry'),
                onPressed: () async {
                  await fleet.refresh();
                  if (mounted && widget.machines.all.contains(machine)) {
                    setState(() => _sectionRetries[machine] = (_sectionRetries[machine] ?? 0) + 1);
                    await _readMachineSection(machine, section);
                  }
                },
                child: const Text('Try again'),
              ),
            ),
          ],
        ];
        final placeKey = ShellPlace(Section.machine, machine: machine, machineSection: section).key;
        final LeafHead head = (
          id: 'machine-section $placeKey',
          path: _machineSectionPath(machine),
          pathKey: ValueKey('machine-section-path ${machine.name}'),
          notices: notices,
          stale: !answering,
          filter: _sectionFilters.putIfAbsent(placeKey, TextEditingController.new),
        );
        // A section drawn as a leaf names itself; Tasks and Projects keep the head drawn here.
        final leaf = opened == null && section != MachineSection.tasks && section != MachineSection.projects;
        final body =
            opened ??
            switch (section) {
              MachineSection.tasks => _workArea(onlyMachine: machine),
              MachineSection.vault => _machineVault(machine, tools, head),
              MachineSection.projects => ListView(
                padding: const EdgeInsets.all(Space.normal),
                children: [
                  const WaitingAction(label: 'Put a project on…'),
                  FilteredListSection(
                    key: ValueKey('machine-projects ${machine.name}'),
                    title: 'Projects',
                    storageId: 'machine-projects ${machine.name}',
                    rows: [
                      for (final row in machineProjectRows(
                        machine: machine,
                        machines: widget.machines,
                        onProject: (project) => _openPageProject(
                          machine,
                          project,
                          from: ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects),
                        ),
                        projectCommands: (project) => _pageProjectCommands(machine, project),
                      ))
                        (words: row.name, child: row.row),
                    ],
                  ),
                ],
              ),
              MachineSection.managing =>
                _hasMachineAdmins(machine)
                    ? _machineOnePage(machine.hostCard!.name, onlyAdmins: true, path: _machineSectionPath(machine))
                    : _machineFacts(managing: true, head: head),
              _ => _machineToolPage(machine, section, tools, head),
            };
        // An answering machine's Tasks list draws this head itself, with its count and filter.
        final ownHead =
            !leaf && (section != MachineSection.tasks || opened != null || fleet.refusal != null || !answering);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ownHead)
              Padding(
                padding: const EdgeInsets.all(Space.normal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHead(
                      title: section.label,
                      path: _machineSectionPath(machine),
                      pathKey: ValueKey('machine-section-path ${machine.name}'),
                    ),
                    ...notices,
                  ],
                ),
              ),
            Expanded(
              child: opened != null || answering || leaf
                  ? body
                  : ExcludeFocus(
                      child: IgnorePointer(
                        child: Opacity(opacity: Opacities.stale, child: body),
                      ),
                    ),
            ),
            if (opened != null || section != MachineSection.tasks && section != MachineSection.managing)
              StatusLine(
                fleet: fleet,
                operations: widget.operations,
                machine: machine.name,
                cannotNotify: widget.notifications.problem,
                highlighted: widget.shell.highlight == 'operations.show',
                onShowOperations: widget.shell.openOperations,
              ),
          ],
        );
      },
    );
  }

  Widget _machineVault(Machine machine, MachineTools tools, LeafHead head) {
    final backend = widget.machines.of(machine).backend;
    final state = tools.vault.state;
    final commands = [
      for (final command in _machineMenu(on: machine))
        if (command.id.startsWith('vault.') && command.id != 'vault.show') command,
    ];
    final primaryId = state?.exists == false
        ? 'vault.make'
        : state?.readable == false
        ? 'vault.passphrase'
        : null;
    final primary = commands.where((command) => command.id == primaryId).firstOrNull;
    return VaultView(
      key: const Key('vault-view'),
      vault: tools.vault,
      head: head,
      actions: [
        if (primary != null)
          Tooltip(
            message: primary.unavailable ?? primary.label,
            child: FilledButton(
              key: Key(primary.id),
              onPressed: primary.available ? primary.run : null,
              child: Text(primary.label),
            ),
          ),
        const WaitingAction(label: 'Store an entry…'),
        CommandMenu(
          key: const Key('vault-actions'),
          commands: commands,
          tooltip: 'What can be done with this vault',
          highlight: widget.shell.highlight,
          onShown: widget.shell.shown,
        ),
      ],
      notes: [
        if (primary?.unavailable case final reason?) Text(reason),
        const Text('No value is shown, copied or logged.'),
      ],
      onRevoke: (slot) => unawaited(tools.run(() => tools.vault.devices.revoke(backend, slot))),
      onUnlockHere: unlockCommandFor(machine) != null ? () => unawaited(_unlockMachine(machine)) : null,
      onMakeHere: makeCommandFor(machine) != null ? () => unawaited(_makeTheVault(on: machine)) : null,
      onGrant: (credential) => unawaited(_grant(credential, on: machine)),
    );
  }

  final _providerCards = <Machine, GlobalKey>{};
  final _destinationCards = <Machine, GlobalKey>{};
  final _sectionRetries = <Machine, int>{};
  final _sectionReadAt = <String, DateTime>{};
  final _sectionFilters = <String, TextEditingController>{};

  void _revealProviders(Machine machine) {
    final there = _providerCards[machine]?.currentContext;
    if (there != null && there.mounted) unawaited(Scrollable.ensureVisible(there));
  }

  Future<void> _importProvider(Machine machine, MachineTools tools, String? agent) async {
    if (!_stillWatching(machine, tools)) return;
    final backend = widget.machines.of(machine).backend;
    await tools.run(() => tools.authentication.importFor(backend, agent: agent));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.shell.place.machine == machine &&
          widget.shell.place.machineSection == MachineSection.agents) {
        _revealProviders(machine);
      }
    });
  }

  Widget _machineToolPage(Machine machine, MachineSection section, MachineTools tools, LeafHead head) {
    final backend = widget.machines.of(machine).backend;
    switch (section) {
      case MachineSection.credentials:
        final storesHere = onTheMachine(machine, const ['porelo'], terminal: false) != null;
        return ConnectionsView(
          head: head,
          connections: tools.connections,
          onAdd: () => unawaited(_addAConnection(on: machine)),
          onForget: (match) => unawaited(tools.run(() => tools.connections.forget(backend, match))),
          onStoreInATerminal: storesHere ? () => unawaited(_storeInATerminal(on: machine)) : null,
          onSendAKey: storesHere
              ? ({String? file, String? pasted}) => _sendAKey(file: file, pasted: pasted, on: machine)
              : null,
          keysAt: widget.machines.setup.sshDirectory,
          pick: widget.pickAFile,
          destinations: KeyedSubtree(
            key: _destinationCards.putIfAbsent(machine, GlobalKey.new),
            child: DestinationsDialog(
              key: ObjectKey(backend),
              backend: backend,
              embedded: true,
              filter: head.filter,
              answering: widget.machines.of(machine).reachability == Reachability.connected,
              readAgain: _sectionRetries[machine] ?? 0,
            ),
          ),
        );
      case MachineSection.agents:
        return AgentsView(
          head: head,
          inventory: tools.inventory,
          subtitle:
              '${AgentsView.countWords(tools.inventory)} · ${AuthenticationView.countWords(tools.authentication)}',
          providers: Command(
            id: 'machine.providers',
            label: 'Providers on this machine',
            group: 'Machine',
            run: () => _revealProviders(machine),
          ),
          providerRows: KeyedSubtree(
            key: _providerCards.putIfAbsent(machine, GlobalKey.new),
            child: AuthenticationView(
              authentication: tools.authentication,
              filter: head.filter,
              onImport: (agent) => unawaited(_importProvider(machine, tools, agent)),
            ),
          ),
        );
      case MachineSection.health:
        return HostReadinessView(
          head: head,
          readiness: tools.readiness,
          machine: machine.name,
          onCheckAgain: () => unawaited(_readMachineSection(machine, MachineSection.health)),
        );
      case MachineSection.vault:
      case MachineSection.tasks:
      case MachineSection.projects:
      case MachineSection.managing:
        return const SizedBox.shrink();
    }
  }

  Widget _machinesFacts() {
    final opened = _opened();
    if (opened != null) return opened;
    final machines = widget.machines;
    final answering = machines.all
        .where((machine) => machines.of(machine).reachability == Reachability.connected)
        .length;
    final read = answering > 0 && machines.all.every((machine) => machines.of(machine).listRead);
    final rows = machinesPageRows(machines, _hostRuns);
    return FactsPage(
      title: 'My machines',
      highlight: widget.shell.highlight,
      settings: widget.settings,
      explanationId: 'machines',
      explanation: const [
        (
          title: 'What is in My machines?',
          words: 'Where work runs. Its projects are under My projects, and its work under Work.',
        ),
      ],
      facts: [
        (
          label: 'Machines',
          value:
              '${rows.preparations.length + listedMachines(machines).where((machine) => !rows.preparations.any((run) => run.name == machine.name)).length}',
          known: true,
        ),
        (label: 'State', value: '$answering answering · ${rows.preparations.length} in preparation', known: true),
        (
          label: 'Work',
          value: read
              ? '${_attention.machinesOnce.fold<int>(0, (sum, machine) => sum + machines.of(machine).tasks.length)}'
              : 'not read — no complete answer from the machines',
          known: read,
        ),
        (
          label: 'Needs you',
          value: read ? '${_attention.needingSomebody}' : 'not read — no complete answer from the machines',
          known: read,
        ),
      ],
      commands: [
        ..._commands().where(
          (command) =>
              {'machines.add', 'refresh.all', 'everywhere.panic'}.contains(command.id) ||
              command.id == 'host.prepare' && _organization == null,
        ),
      ],
      primary: 'machines.add',
    );
  }

  Widget _machineFacts({bool managing = false, LeafHead? head}) {
    final machine = _pageMachine(widget.shell.itemMachine ?? widget.machines.current);
    final preparation = _hostRuns.preparing.where((run) => run.name == machine.name).firstOrNull;
    if (preparation != null) {
      final opened = _opened(on: machine);
      if (opened != null) return opened;
      return FactsPage(
        title: preparation.name,
        highlight: widget.shell.highlight,
        facts: [
          (label: 'State', value: hostPreparationWords(preparation), known: true),
          (
            label: 'Setup',
            value: preparation.problem ?? preparation.session.fix ?? preparation.session.stepText,
            known: true,
          ),
        ],
        commands: _preparationCommands(preparation),
      );
    }
    final watched = widget.machines.all.contains(machine);
    final fleet = watched ? widget.machines.of(machine) : null;
    final tools = watched ? _toolsFor(machine) : null;
    final ownVault = tools?.vault;
    Widget withStatus(Widget page) => !watched
        ? page
        : Column(
            children: [
              Expanded(child: page),
              StatusLine(
                fleet: fleet!,
                operations: widget.operations,
                machine: machine.name,
                cannotNotify: widget.notifications.problem,
                highlighted: widget.shell.highlight == 'operations.show',
                onShowOperations: widget.shell.openOperations,
              ),
            ],
          );
    if (watched) {
      final ownFleet = fleet!;
      _keepTheVaultButtonTrue(machine, ownFleet);
      if (ownFleet.refusal case final refusal?) return withStatus(RefusalView(refusal: refusal, fleet: ownFleet));
      final opened = _opened(on: machine);
      if (opened != null) return withStatus(opened);
    }
    final vault = ownVault?.about == machine.name ? ownVault?.state : null;
    final read = fleet?.listRead ?? false;
    if (managing && head != null && watched && !(machine.hostCard != null && _organization != null)) {
      return withStatus(_managingPage(machine, fleet!, tools!, vault, head));
    }
    final onePage = _onTheOrganizationsPage(machine);
    final page = FactsPage(
      embedded: onePage,
      title: machine.name,
      head: head == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHead(
                  title: MachineSection.managing.label,
                  path: head.path,
                  pathKey: head.pathKey,
                  subtitle:
                      '${fleet?.reachability == Reachability.connected ? 'Connected' : 'Not answering'}'
                      ' · Porelo ${fleet?.info?.version ?? 'not read'}',
                ),
                ...head.notices,
              ],
            ),
      // A machine with an organization's card is named, with its state and version, in its page's one head.
      identity: onePage
          ? null
          : Text('${machine.where}${machineKind(widget.machines, machine)}', key: const Key('machine-kind')),
      highlight: widget.shell.highlight,
      path: [(label: 'My machines', go: () => _chooseTreePlace(const ShellPlace(Section.machines), true))],
      busy: (fleet?.busy ?? false) || (ownVault?.busy ?? false),
      facts: [
        if (!onePage) ...[
          (label: 'Last read', value: 'not read — the connection does not report a read time', known: false),
          (
            label: 'Porelo',
            value: fleet?.info?.version ?? 'not read — Porelo has not answered',
            known: fleet?.info != null,
          ),
          (
            label: 'State',
            value: fleet?.reachability == Reachability.connected ? 'Connected' : 'Not answering',
            known: true,
          ),
        ],
        (
          label: 'Vault',
          value: vault == null
              ? 'not read — this machine has not answered about its vault'
              : !vault.exists
              ? 'No vault yet'
              : vault.readable
              ? 'Open · ${vault.credentials.length} entries'
              : 'Shut · entry count not read',
          known: vault != null,
        ),
        (label: 'Tasks', value: read ? '${fleet!.tasks.length}' : 'not read — Porelo has not answered', known: read),
        (
          label: 'Projects',
          value: read ? '${projectsOnMachine(widget.machines, machine).length}' : 'not read — Porelo has not answered',
          known: read,
        ),
        (
          label: 'Health',
          value: tools?.readiness.health != null
              ? tools!.readiness.verdict
              : 'not read — run Check whether this machine can run anything',
          known: tools?.readiness.health != null,
        ),
        (label: 'Address', value: machine.where, known: true),
      ],
      commands: watched
          ? [
              for (final command in [..._machineMenu(on: machine), _machinePanic(machine)])
                if ({
                      'fleet.refresh',
                      'vault.shut',
                      'vault.passphrase',
                      'vault.make',
                      'machine.doctor',
                      'machine.panic',
                      'machine.stop',
                      'machine.clear',
                    }.contains(command.id) ||
                    command.id.contains('takeDown'))
                  if (command.id != 'vault.shut' || vault?.readable == true)
                    if (command.id != 'vault.passphrase' || vault?.readable != true)
                      command.unless(
                        command.id.startsWith('vault.') && vault == null
                            ? 'This machine has not answered about its vault.'
                            : null,
                      ),
            ]
          : [],
      primary: managing
          ? 'machine.stop'
          : vault?.readable == false
          ? 'vault.passphrase'
          : 'fleet.refresh',
      menuCommands: watched
          ? _machineMenu(on: machine)
                .where(
                  (command) =>
                      !{
                        'fleet.refresh',
                        'vault.shut',
                        'vault.passphrase',
                        'vault.make',
                        'machine.doctor',
                        'machine.stop',
                        'machine.clear',
                      }.contains(command.id) &&
                      !command.id.contains('takeDown'),
                )
                .map(
                  (command) => command.unless(
                    command.id.startsWith('vault.') && command.id != 'vault.show' && vault == null
                        ? 'This machine has not answered about its vault.'
                        : null,
                  ),
                )
                .toList()
          : [],
      tools: watched && ownVault != null && vault != null ? _vaultButtonsFor(machine, fleet!, ownVault) : null,
    );
    return withStatus(onePage ? _machineOnePage(machine.hostCard!.name, work: page) : page);
  }

  /// A machine's managing page: its head once, its facts as four tiles, its actions with the
  /// reason a waiting one waits beside it, and what cannot be undone apart.
  Widget _managingPage(Machine machine, FleetModel fleet, MachineTools tools, VaultState? vault, LeafHead head) {
    final answering = fleet.reachability == Reachability.connected;
    final all = [..._machineMenu(on: machine), _machinePanic(machine)];
    Command noVault(Command command) => command.unless(
      command.id.startsWith('vault.') && command.id != 'vault.show' && vault == null
          ? 'This machine has not answered about its vault.'
          : null,
    );
    Command? byId(String id) => all.where((command) => command.id == id).map(noVault).firstOrNull;
    final actionIds = [
      'machine.doctor',
      'fleet.refresh',
      if (vault?.readable == true) 'vault.shut',
      if (vault != null && vault.exists && !vault.readable) 'vault.open',
      if (vault?.readable != true) 'vault.passphrase',
      // Made already is done: only a machine without one, or not read, is offered it.
      if (vault == null || !vault.exists) 'vault.make',
      'machine.stop',
    ];
    const dangerIds = {'machine.panic', 'machine.clear'};
    final placed = {...actionIds, ...dangerIds, 'vault.make', 'vault.shut', 'vault.passphrase', 'vault.open'};
    final readiness = tools.readiness;
    final health = readiness.health;
    final missing = readiness.probes.where((probe) => probe.stopsIt).map((probe) => probe.name).toList();
    final notFine = readiness.worthReading.map((probe) => probe.name).toList();
    final read = fleet.listRead;
    final readAt = howLongSince(
      _sectionReadAt[ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.managing).key],
    );
    final kind = machine.kind == 'wsl'
        ? machine.where
        : machine.needsATunnel
        ? 'Over ssh'
        : 'This computer';
    return ManagingPage(
      busy: fleet.busy || tools.vault.busy,
      highlight: widget.shell.highlight,
      head: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHead(
            title: machine.name,
            titleInAppBar: false,
            pathTitle: MachineSection.managing.label,
            path: head.path,
            pathKey: head.pathKey,
            titleChip: StateChip(answering ? 'Connected' : 'Not answering'),
            subtitle: '$kind · Porelo ${fleet.info?.version ?? 'not read'}',
          ),
          ...head.notices,
        ],
      ),
      facts: [
        (
          id: 'connection',
          label: 'Connection',
          icon: Icons.lan_outlined,
          value: answering ? 'Connected' : 'Not answering',
          detail: machine.where,
          known: true,
          code: true,
        ),
        (
          id: 'vault',
          label: 'Vault',
          icon: Icons.key_outlined,
          value: vault == null
              ? 'not read'
              : !vault.exists
              ? 'None'
              : vault.readable
              ? 'Open'
              : 'Shut',
          detail: vault == null
              ? 'this machine has not answered about its vault'
              : !vault.exists
              ? 'No vault yet'
              : vault.readable
              ? counted(vault.credentials.length, 'entry', 'entries')
              : 'entry count not read',
          known: vault != null,
          code: false,
        ),
        (
          id: 'work',
          label: 'Work',
          icon: Icons.work_outline,
          value: read
              ? counted(fleet.tasks.where((task) => task.running).length, 'task running', 'tasks running')
              : 'not read',
          detail: read
              ? counted(projectsOnMachine(widget.machines, machine).length, 'project', 'projects')
              : 'Porelo has not answered',
          known: read,
          code: false,
        ),
        (
          id: 'health',
          label: 'Health',
          icon: Icons.health_and_safety_outlined,
          value: health == null
              ? 'not read'
              : health.ready
              ? 'Can run work'
              : 'Cannot run work',
          detail: health == null
              ? 'run Check whether this machine can run anything'
              : missing.isNotEmpty
              ? 'Missing: ${missing.join(', ')}'
              : notFine.isNotEmpty
              ? 'Not fine: ${notFine.join(', ')}'
              : 'Nothing is missing',
          known: health != null,
          code: false,
        ),
      ],
      primary: 'machine.doctor',
      actions: [for (final id in actionIds) ?byId(id)],
      danger: [
        if (byId('machine.panic') case final panic?)
          (
            command: panic,
            title: 'Stop everything on this machine',
            words: 'Stops every task at once. Their work stays.',
            button: 'Stop everything',
          ),
        if (byId('machine.clear') case final clear?)
          (
            command: clear,
            title: 'Clear this machine of everything Porelo put there',
            words: 'Removes tasks, images and settings. Asks again before it starts.',
            button: 'Clear this machine…',
          ),
      ],
      menuTooltip: 'What ${machine.name} can be told to do',
      menuCommands: [
        for (final command in _machineMenu(on: machine))
          if (!placed.contains(command.id)) noVault(command),
      ],
      lastRead: readAt == null ? 'Last read: the connection does not report a read time.' : 'Last read: $readAt ago.',
    );
  }

  List<Command> _organizationFactsCommands() => [
    ...organizationAddressCommands(context, _organization),
    if (_organization?.view == null) makeMyCardCommand(context, _organization),
    if (_organization case final organization?)
      Command(
        id: 'organization.refresh',
        label: 'Refresh',
        group: 'Organization',
        home: Home.organizationRow,
        run: () => unawaited(organization.refresh()),
      ),
  ];

  Widget _organizationsFacts({bool one = false}) => ListenableBuilder(
    listenable: Listenable.merge([?_organization, ?widget.identity]),
    builder: (context, _) {
      final organization = _organization;
      final opened = _opened();
      if (opened != null) return opened;
      final view = organization?.view;
      final card = view?.myCard;
      final title = one ? view?.name ?? 'Organization' : 'Organizations';
      return FactsPage(
        title: title,
        settings: widget.settings,
        highlight: widget.shell.highlight,
        explanationId: 'organization',
        explanation: const [
          (
            title: 'What is the Porelo organization?',
            words:
                'Who manages it, its people with their cards, its projects with their members, and its machines. '
                'Porelo asks it whom to trust before anyone gets onto a machine.',
          ),
        ],
        warnings: [
          ?organization?.problem,
          if (view?.stale ?? false) 'The store could not be reached; these are the last facts read.',
          ...?view?.notes,
          if (one &&
              view != null &&
              view.isOwner &&
              view.owners.length == 1 &&
              !view.ownersWithBackup.contains(view.me))
            'Only owner, no backup key',
        ],
        path: one
            ? [(label: 'Organizations', go: () => _chooseTreePlace(const ShellPlace(Section.organizations), true))]
            : [],
        busy: organization?.busy ?? false,
        facts: [
          if (one)
            (
              label: 'Last read',
              value: organization?.readAt?.toLocal().toString() ?? 'not read — no organization answered',
              known: organization?.readAt != null,
            ),
          (
            label: 'Working in',
            value: view?.name ?? 'None read — ${organization?.problem ?? 'no organization is configured'}',
            known: view != null,
          ),
          (
            label: 'Your card',
            value: card == null ? 'not read — no card was read for this person' : '${view!.me} · ${card.standing.name}',
            known: card != null,
          ),
          if (one) ...[
            (
              label: 'Your role',
              value: view == null
                  ? 'not read — no organization answered'
                  : view.isOwner
                  ? 'Organization owner'
                  : view.isOrganizationAdmin
                  ? 'Organization Admin'
                  : 'Project and machine roles are listed on their pages',
              known: view != null,
            ),
            (
              label: 'People',
              value: view == null ? 'not read — no organization answered' : '${view.persons.length}',
              known: view != null,
            ),
            (
              label: 'Projects',
              value: view == null ? 'not read — no organization answered' : '${view.projects.length}',
              known: view != null,
            ),
            (
              label: 'Machines',
              value: view == null ? 'not read — no organization answered' : '${view.hosts.length}',
              known: view != null,
            ),
            (
              label: 'Organization owners',
              value: view == null ? 'not read — no organization answered' : '${view.owners.length}',
              known: view != null,
            ),
            (label: 'Kept in', value: view?.keptIn ?? 'not read — no organization answered', known: view != null),
            (
              label: 'Proposed cards',
              value: 'not read — the organization source does not list proposed cards',
              known: false,
            ),
          ],
        ],
        commands: [
          ..._organizationFactsCommands().where((command) => one || command.id != 'organization.refresh'),
          if (one &&
              view != null &&
              view.isOwner &&
              view.owners.length == 1 &&
              !view.ownersWithBackup.contains(view.me))
            Command(
              id: 'organization.owners',
              label: 'Look at the organization owners',
              group: 'Organization',
              home: Home.organizationRow,
              run: () => _chooseTreePlace(
                ShellPlace(
                  Section.organization,
                  organization: view.name,
                  organizationSection: OrganizationSection.owners,
                ),
                false,
              ),
            ),
        ],
        waiting: one
            ? ['Propose a card…', 'Accept a proposed card…', 'Leave ${view?.name ?? 'this organization'}…']
            : ['Join an organization…'],
        primary: view == null ? 'createOrganization' : 'chooseOrganization',
      );
    },
  );

  /// Where you are, and what belongs to no machine: the finder, another machine, options, about.
  PreferredSizeWidget _appBar(WindowSize size, List<Command> commands) {
    final machine = widget.machines.current;
    final project = _fleet.selectedProject;
    final title = switch (widget.shell.section) {
      Section.machine =>
        widget.shell.place.machineSection?.labelOn(
              organizationCard: _hasMachineAdmins(widget.shell.place.machine ?? machine),
            ) ??
            (widget.shell.itemMachine ?? machine).name,
      Section.organization =>
        widget.shell.place.organizationSection?.label ??
            widget.shell.place.organization ??
            _organization?.view?.name ??
            'Organization',
      Section.project =>
        '${(widget.shell.itemMachine ?? machine).name} › ${widget.shell.itemProject ?? project?.label ?? ''}',
      final section => section.label,
    };
    return AppBar(
      // Keyed, so a walk can point at it when a narrow window keeps the rail behind it.
      leading: size.showsTreeBeside
          ? null
          : IconButton(
              key: const Key('open-rail'),
              focusNode: _menuFocus,
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffold.currentState?.openDrawer(),
            ),
      title: Text(title, key: const Key('app-title'), overflow: TextOverflow.ellipsis),
      actions: <Widget>[
        // Left of the actions from tablet width up, as on the desktop; on the phone after the ⋮.
        if (size != WindowSize.compact) _organizationButton(size),
        IconButton(
          key: const Key('stop-everywhere-bar'),
          tooltip: 'Stop everything on every machine',
          icon: Icon(Icons.pan_tool_outlined, color: Theme.of(context).colorScheme.error),
          onPressed: commands
              .where((command) => command.id == 'everywhere.panic' && command.available)
              .firstOrNull
              ?.run,
        ),
        if (!size.showsBarActions) ...[
          _barOverflow(commands),
          if (size == WindowSize.compact) _organizationButton(size),
        ],
        if (size.showsBarActions) ...[
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
      ],
    );
  }

  /// Closes the drawer the tree is in, when it is in one, before going where it was asked.
  void _leaveDrawer() {
    final scaffold = _scaffold.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
  }

  String? _treeMachineState(Machine machine) {
    if (!widget.machines.all.contains(machine)) return 'Not connected yet';
    final tunnel = widget.machines.tunnels.of(machine);
    return railMachineState(
      reach: widget.machines.of(machine).reachability,
      problem: tunnel?.problem,
      admitting: tunnel?.admitting ?? false,
    );
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
      ?_organization,
      for (final machine in widget.machines.all) widget.machines.of(machine),
    ]),
    builder: (context, _) {
      final rows = machinesPageRows(widget.machines, _hostRuns);
      final projectsRead =
          widget.machines.all.any((machine) => widget.machines.of(machine).reachability == Reachability.connected) &&
          _attention.machinesOnce.every((machine) => widget.machines.of(machine).listRead);
      return ShellRail(
        section: widget.shell.section,
        place: widget.shell.place,
        foldedOpen: widget.shell.foldedOpen,
        onFold: widget.shell.toggleFold,
        onPlace: _chooseTreePlace,
        organizations: [?_organization?.view],
        organizationsKnown: _organization == null || _organization.view != null || _organization.noOrganization,
        machinesWithSections: {
          for (final machine in widget.machines.all)
            if (!rows.preparations.any((run) => run.name == machine.name)) machine.name,
        },
        machinesWithAdmins: {
          for (final machine in widget.machines.all)
            if (_hasMachineAdmins(machine)) machine.name,
        },
        machineEntries: [
          for (final run in rows.preparations)
            (
              machine:
                  widget.machines.all.where((machine) => machine.name == run.name).firstOrNull ??
                  Machine(name: run.name, socketPath: ''),
              state: hostPreparationWords(run),
            ),
          for (final machine in listedMachines(widget.machines))
            if (!rows.preparations.any((run) => run.name == machine.name))
              (machine: machine, state: _treeMachineState(machine)),
        ],
        running: !_attention.workRead()
            ? null
            : <int>[
                for (final machine in _attention.machinesOnce)
                  widget.machines.of(machine).tasks.where((task) => task.running).length,
              ].fold<int>(0, (sum, each) => sum + each),
        work: _attention.workCount,
        needing: _attention.needingCount,
        machines:
            rows.preparations.length +
            listedMachines(widget.machines)
                .where((row) => !rows.preparations.any((run) => run.name == row.name))
                .length,
        projects:
            _organization != null && !_machineProjects && _organization.view == null ||
                (_organization == null || _machineProjects) && !projectsRead
            ? null
            : projectsInRail(
                _organization?.view,
                fromOrganization: _organization != null && !_machineProjects,
                onMachines: listedMachines(widget.machines)
                    .fold<int>(0, (count, machine) => count + projectsOnMachine(widget.machines, machine).length),
              ),
        forges: !_forges.loaded || _forges.busy ? null : listedForges(_forges.allEntries, _heldConnections).length,
        width: width,
        onGo: (section) {
          _leaveDrawer();
          setState(() {
            _organizationProject = null;
            _machineProjects = false;
            _organizationHost = null;
            _organizationHostFrom = null;
            _organizationProjectFrom = null;
          });
          if (section == Section.work) {
            _workView.search.clear();
          }
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

  /// Every project on every machine, and the ways to set one up: setting up, out of the daily way.
  /// Today's list of a machine's projects, with the way back to the organization's where it is opened from there.
  /// What the page [id] is for, in [parts], above [page]. Its `i` stands on the list titled [title]; where
  /// the page has no such list, [ownHead] gives it a head of its own.
  Widget _explained(
    String id,
    String title,
    List<({String title, String words})> parts,
    Widget page, {
    bool ownHead = false,
  }) => PageExplanationScope(
    title: title,
    id: id,
    settings: widget.settings,
    parts: id == 'forges' || id == 'projects' || id == 'needs-you' ? parts : const [],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (ownHead) PageHead(title: title, id: id, settings: widget.settings),
        if (id != 'forges' && id != 'projects' && id != 'needs-you')
          PageExplanation(key: ValueKey<String>('explanation $id'), id: id, settings: widget.settings, parts: parts),
        Expanded(child: page),
      ],
    ),
  );

  Widget _explainedProjects(Widget page) =>
      _explained('projects', 'My projects', const <({String title, String words})>[
        (
          title: 'What is in My projects?',
          words: 'How work runs: its repositories, who reviews what it pushes, whom it may talk to.',
        ),
      ], page);

  Widget _projectsPage() =>
      _opened() ??
      (_organization == null || _machineProjects
          ? null
          : _organizationProject != null
          ? _organizationProjects(_organization)
          : _explainedProjects(_organizationProjects(_organization))) ??
      _explainedProjects(
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _attention,
            widget.notifications,
            for (final machine in widget.machines.all) widget.machines.of(machine),
          ]),
          builder: (context, _) => ProjectsPage(
            title: _organization == null ? 'My projects' : 'Projects on my machines',
            path: _machineProjects
                ? [(label: 'My projects', go: () => setState(() => _machineProjects = false))]
                : const [],
            machines: widget.machines,
            muted: widget.notifications.muted,
            highlight: widget.shell.highlight,
            onShown: widget.shell.shown,
            onProject: (machine, project) {
              _openPageProject(machine, project);
            },
            menuFor: _pageProjectCommands,
          ),
        ),
      );

  /// How the work page was left, kept here so it stays while something takes its place.
  final WorkView _workView = WorkView();

  /// Every piece of work on every machine, or what is open over it.
  Widget _workArea({Machine? onlyMachine}) {
    // A refusal takes the place of the page, as on the machine's: a removal the machine refused,
    // said only in the status line, looked like nothing happening (walk 9).
    final ownFleet = onlyMachine == null ? _fleet : widget.machines.of(onlyMachine);
    final refusal = ownFleet.refusal;
    final opened = refusal != null ? RefusalView(refusal: refusal, fleet: ownFleet) : _opened(on: onlyMachine);
    // Nothing tells of a refusal but the drawing of it, and what took the page's place took the session's.
    if (opened != null) WidgetsBinding.instance.addPostFrameCallback((_) => _leaveTheSessionWithItsPage());
    final page =
        opened ??
        WorkPage(
          head: onlyMachine == null
              ? PageHead(title: 'Work', id: 'work', settings: widget.settings)
              : PageHead(
                  title: MachineSection.tasks.label,
                  path: _machineSectionPath(onlyMachine),
                  pathKey: ValueKey('machine-section-path ${onlyMachine.name}'),
                ),
          explanation: PageExplanation(
            id: 'work',
            settings: widget.settings,
            parts: const <({String title, String words})>[
              (
                title: 'What is Work?',
                words: 'All work on your machines: what is running, what has stopped, and the way to its terminal.',
              ),
            ],
          ),
          view: _workView,
          listFocus: _openedFocus,
          reveal: widget.shell.highlight != null && _fleet.selectedTask != null
              ? '${widget.machines.current.name}/${_fleet.selectedTask!.name}'
              : null,
          machines: widget.machines,
          onlyMachine: onlyMachine,
          attention: _attention,
          onNewWork:
              (onlyMachine == null
                  ? widget.machines.all.any((each) => widget.machines.of(each).reachability == Reachability.connected)
                  : widget.machines.all.contains(onlyMachine) &&
                        widget.machines.of(onlyMachine).reachability == Reachability.connected)
              ? () => unawaited(_newWork(on: onlyMachine))
              : null,
          newWorkUnavailable: onlyMachine == null ? 'no machine answers.' : '${onlyMachine.name} is not answering.',
          onAddAMachine: _addAMachine,
          running: (context) => RunningView(
            machines: widget.machines,
            onlyMachine: onlyMachine,
            attention: _attention,
            view: _workView,
            sessions: widget.sessions,
            logs: widget.logs,
            focusNode: _openedFocus,
            onAnswer: () => widget.shell.goTo(Section.attention),
            onReadLog: _readLogOf,
            onImageSettings: _showImageSettings,
          ),
          tile: _workRow,
        );
    // What an action from a tile said, of the machine it acted on: the work page has tiles of every
    // machine, and an answer nobody saw was an action that seemed to do nothing.
    final machine = onlyMachine ?? widget.machines.current;
    return Column(
      children: <Widget>[
        Expanded(child: page),
        StatusLine(
          fleet: ownFleet,
          operations: widget.operations,
          machine: machine.name,
          cannotNotify: widget.notifications.problem,
          highlighted: false,
          onShowOperations: widget.shell.openOperations,
        ),
      ],
    );
  }

  /// One row of the list of work.
  Widget _workRow(Tile tile) {
    final task = tile.task;
    final selected =
        task != null && widget.machines.current == tile.machine && tile.fleet.selectedTask?.name == task.name;
    final place = task == null ? null : WorkView.placeOf(tile.machine.name, task.name);
    return WorkRow(
      tile: tile,
      actions: task == null ? const <Command>[] : _tileActions(tile),
      terminalEnded: task != null && _workView.terminalEnded(tile.machine.name, task),
      selected: selected,
      // Where the finder went to one of its commands, the selected work's menu shows it.
      highlight: selected ? widget.shell.highlight : null,
      onShown: widget.shell.shown,
      onSelect: task == null ? null : () => _actOn(tile),
      onFollow: place == null ? null : () => _workView.showTab(place),
      onNewTerminal: task == null ? null : () => _workView.showNewTerminal(tile.machine.name, task),
      onReadLog: task == null ? null : () => _readLogOf(tile),
      onImageSettings: task == null ? null : () => _showImageSettings(tile),
      onSeeInNeedsYou: () => widget.shell.goTo(Section.attention),
    );
  }

  /// Shows what a row's image was built with, read from its own machine.
  void _showImageSettings(Tile tile) {
    final task = tile.task;
    if (task == null) return;
    unawaited(showImageSettings(context, backend: tile.fleet.backend, task: task.name));
  }

  /// Opens a log of [tile]'s work: what its agent wrote where it wrote one, or the ones it has to choose
  /// from, since work in a terminal writes none of its own. Opening it is seeing how the work ended.
  void _readLogOf(Tile tile) {
    final task = tile.task;
    if (task == null) return;
    _attention.putAwayTheEnd(tile);
    _actOn(tile);
    if (task.mode == Mode.unattended) {
      _enlargeConsole(tile);
    } else {
      unawaited(_askWhichLog(task));
    }
  }

  /// Starts new work: where first, when there is more than one machine that answers.
  Future<void> _newWork({Machine? on, bool askTheProject = false}) async {
    final answering = <Machine>[
      for (final machine in widget.machines.all)
        if (widget.machines.of(machine).reachability == Reachability.connected) machine,
    ];
    if (answering.isEmpty) return;
    var where = on ?? (answering.length == 1 ? answering.single : null);
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
        if (project.name != defaultProject && (project.canBeActedOn || project.project.carried)) project,
    ];
    // Then in which project, or in none: work in the Default project is default, every machine's. Asked on a machine
    // that carries one project besides Default, the window knows it: the form opens in it, with a way to another.
    final known = on != null && !askTheProject && projects.length == 1;
    final chosen = projects.isEmpty
        ? defaultProject
        : known
        ? projects.single.name
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
                    child: Text('Default'),
                  ),
                ),
              ],
            ),
          );
    if (chosen == null || !mounted) return;
    // Default is default, which a machine need not list among its projects.
    if (chosen == defaultProject) return _startInDefault();
    fleet.selectProject(chosen);
    var another = false;
    await _startWork(onChangeProject: known ? () => another = true : null);
    if (another && mounted && widget.machines.all.contains(where)) await _newWork(on: where, askTheProject: true);
  }

  /// What needs a person. A tile leads to where its work lives.
  Widget _needsYou() {
    final opened = _opened();
    if (opened != null) return opened;
    return _explained(
      'needs-you',
      'Needs you',
      const <({String title, String words})>[
        (
          title: 'What is Needs you?',
          words: 'What waits for a person: questions, reviews and work that stopped. Nothing else asks for your attention.',
        ),
      ],
      Focus(
        focusNode: _openedFocus,
        child: AttentionView(
          onOpened: () {
            for (final machine in widget.machines.all) {
              widget.machines.of(machine).mailboxes.askAgain();
            }
          },
          attention: _attention,
          onCreateRepository: (project) {
            if (_organization case final organization?) {
              unawaited(
                showDialog<void>(context: context, builder: (_) => CreateRepositoryDialog(organization, project)),
              );
            }
          },
          onGiveToken: (host) {
            setState(() {
              _organizationHostFrom = const ShellPlace(Section.attention);
              _organizationHost = host;
            });
            widget.shell.goTo(Section.machines);
          },
          onOpenHost: (project) {
            final run = _hostRuns.of(project);
            if (run != null) unawaited(_openHostRun(run));
          },
          unlockFor: _unlockFor,
          onRemoveProject: (machine, project) =>
              unawaited(_previewProjectRemoval(widget.machines.of(machine), project.name)),
          whyNoRemoval: _whyNoRemoval,
          onDecide: (tile, prompt, {required allow}) =>
              tile.fleet.clearance.decide(tile.fleet.backend, prompt, allow: allow),
          onPutAway: (tile, prompt) {
            tile.fleet.clearance.forget(prompt);
            _attention.questionPutAway(tile.machine, prompt);
          },
          onOpenOperation: (operation) => widget.shell.openOperation(operation.id),
          actionsFor: _tileActions,
          onSelect: _goToWork,
          onReadLog: _readLogOf,
          onReview: (tile) {
            _actOn(tile);
            unawaited(_openTheGate(tile.task));
          },
        ),
      ),
    );
  }

  /// Whether *Running* is what is on screen, the one place a terminal is: nothing opened or refused in
  /// its place.
  bool get _runningIsShown =>
      (widget.shell.section == Section.work ||
          widget.shell.section == Section.machine && widget.shell.place.machineSection == MachineSection.tasks) &&
      _workView.running &&
      !widget.shell.anythingOpen &&
      (widget.shell.section != Section.machine || widget.machines.all.contains(widget.shell.place.machine)) &&
      (widget.shell.section == Section.machine && widget.shell.place.machine != null
              ? widget.machines.of(widget.shell.place.machine!).refusal
              : _fleet.refusal) ==
          null;

  /// Leaving the tab's page leaves its session: the agent runs on, and coming back opens it again.
  void _leaveTheSessionWithItsPage() {
    if (widget.sessions.any && !_runningIsShown) unawaited(widget.sessions.leave());
  }

  /// Leaves the wait on the sign-in a failed start offered once its view is no longer open: **the sign-in goes on**
  /// on the machine, which is said; opened again, the view offers it again.
  void _leaveTheSignInsWithTheirView() {
    final open = switch (widget.shell.opened) {
      OperationOpened(:final id) => id,
      _ => null,
    };
    for (final MapEntry(key: id, value: signIn) in _signInsAfterAFailedStart.entries) {
      // Whatever is still out is left too, a start or a question among them: its late answer opens nothing.
      if (id == open || !(signIn.out || signIn.attaching)) continue;
      final left = signIn.leave();
      final machine = widget.machines.all.where((each) => each.name == signIn.machine).firstOrNull;
      if (left != null && machine != null) widget.machines.of(machine).say(left);
    }
  }

  /// One machine: its title and menu, then its projects and work, then what it ran.
  Widget _machineArea() {
    final machine = widget.machines.current;
    final fleet = _fleet;
    final highlight = widget.shell.highlight;
    // A refusal takes the place of whatever was open: it is the most important thing on the
    // screen until somebody has decided about it.
    final refusal = fleet.refusal;
    final opened = refusal != null ? RefusalView(refusal: refusal, fleet: fleet) : _opened();
    _keepTheVaultButtonTrue(machine, fleet);
    return Column(
      children: <Widget>[
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
  void _openPageMachine(Machine machine, {ShellPlace? from}) {
    _organizationHostFrom = from;
    machine = _pageMachine(machine);
    if (widget.machines.all.contains(machine)) widget.machines.select(machine);
    widget.shell.openMachine(machine);
  }

  /// The machine place a project's page was opened from, where it was: the page is then what of the project is on that
  /// machine, and goes back there.
  ShellPlace? _projectFrom;

  /// The place the project's page was opened at from [_projectFrom]: any other way to the page, as the finder's, makes a
  /// new place and forgets the machine.
  ShellPlace? _projectOpenedAt;

  void _openPageProject(Machine machine, String project, {ShellPlace? from}) {
    machine = _pageMachine(machine);
    // An action on the open page opens it again: it keeps where it came from.
    final same =
        widget.shell.section == Section.project &&
        widget.shell.itemMachine == machine &&
        widget.shell.itemProject == project;
    if (!same) _projectFrom = from;
    if (widget.machines.all.contains(machine)) {
      widget.machines.select(machine);
      widget.machines.of(machine).selectProject(project);
    }
    widget.shell.openProject(machine, project);
    _projectOpenedAt = widget.shell.place;
  }

  Machine _pageMachine(Machine machine) =>
      widget.machines.all
          .where((watched) => watched.name == machine.name && watched.socketPath == machine.socketPath)
          .firstOrNull ??
      machine;

  List<Command> _pageProjectCommands(Machine machine, ProjectOnScreen project) {
    final watched = widget.machines.all.contains(machine);
    final answering = watched && widget.machines.of(machine).reachability == Reachability.connected;
    final openWork = Command(
      id: 'work.start',
      label: 'Start work',
      group: 'Projects',
      home: Home.projectMenu,
      unavailable: !answering
          ? 'This machine is not connected.'
          : project.name == defaultProject
          ? null
          : project.canBeActedOn || project.project.carried
          ? StartWork.whyNot(project.project)
          : 'This project is not on this machine.',
      run: () {
        _openPageProject(machine, project.name);
        unawaited(project.name == defaultProject ? _startInDefault() : _startWork());
      },
    );
    return [
      openWork,
      projectWorkCommand(
        open: () {
          _workView.showList(searchFor: project.name == defaultProject ? WorkRow.projectOf(null) : project.name);
          widget.shell.goTo(Section.work);
        },
      ),
      if (watched)
        ..._projectMenu(
          project,
          on: machine,
        ).where((command) => project.name != defaultProject || command.id != 'project.clear'),
      if (watched)
        ...cardHostTransferCommands(
          transfers: _transfers,
          machine: machine,
          project: project.name,
          whyNoRight: _standings.whyNoRight(project.name),
          hasSecrets: centralToken(widget.settings.secretsFile, desk.environment) != null,
          running: _transfersRunning.contains('${machine.name}/${project.name}'),
          start: (direction) => unawaited(_transferInATerminal(machine, project.name, direction)),
        ),
    ];
  }

  /// Pushes the approved main, or takes the central state, in a terminal here: the terminal reads the central token
  /// from the variable this instance was started with, or from the person's secrets file after its master password
  /// is typed there, and hands it to the host's own command on its standard input, so the token never passes through this
  /// program.
  Future<void> _transferInATerminal(Machine machine, String project, ProjectTransfer direction) async {
    final key = '${machine.name}/$project';
    if (!_transfersRunning.add(key)) return;
    setState(() {});
    try {
      // The menu was built from an earlier read; a lock since then must stop this run.
      await _standings.read();
      if (!mounted) return;
      if (_standings.whyNoRight(project) case final why?) {
        _fleet.say(why);
        return;
      }
      await _transferOnce(machine, project, direction);
    } finally {
      _transfersRunning.remove(key);
      if (mounted) setState(() {});
    }
  }

  /// A server just prepared: connects to it from its new card. Its token is a step of its own, on the wizard's last
  /// page or its row, never a dialog that opens by itself.
  Future<void> _hostReady(String host) async {
    try {
      await _connectHost(host);
    } on OrganizationRefused catch (refused) {
      _fleet.say('$host is ready, but this window could not connect to it yet: ${refused.words}');
      return;
    }
    _fleet.say('$host is ready. It waits for your token: Give it your token… on its row.');
  }

  Future<void> _connectHost(String host) async {
    await _organization?.refresh();
    final connections = _hostConnections;
    if (connections == null) {
      throw const OrganizationRefused("This window reads no organization, so it reaches none of its machines.");
    }
    await connections.connect(host);
  }

  /// Every source of a forge token asked for [host], and the one the person chooses given.
  HostTokenStep _hostTokenStep(String host) {
    final view = _organization?.view;
    return HostTokenStep(
      host: host,
      sources: HostTokenSources(
        forge: organizationForgeName(view),
        repository: view?.address,
        address: organizationKeptTokenAddress(view),
        declarations: readThisComputersDeclarations,
        hasKept: _forges.hasToken,
        secrets: () => centralToken(widget.settings.secretsFile, desk.environment),
      ),
      connect: () => _connectHost(host),
      give: (answer) => _giveTokenFrom(host, answer),
      heard: () async {
        final connections = _hostConnections;
        if (connections != null && connections.connected(host)) await connections.progress(host);
      },
    );
  }

  /// The row's *Give it your token…*: the token's own page, every source with what it answered. [atOnce] gives the
  /// entry this computer's Porelo-Vault declares without the page, where it declares one.
  Future<String?> _giveHostToken(String host, {bool atOnce = false}) async {
    final step = _hostTokenStep(host);
    final forge = organizationForgeName(_organization?.view);
    try {
      // Where it is not declared, the page opens on the answers already read.
      if (atOnce && await step.giveAtOnce()) return step.given ? null : step.problem;
      if (!atOnce) unawaited(step.ask());
      if (!mounted) return null;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('organization.tokenPage'),
          title: Text('Give $host your $forge token, once'),
          content: SizedBox(
            width: Sizes.dialog,
            child: SingleChildScrollView(
              child: HostTokenPanel(
                step: step,
                onSignIn: () {
                  Navigator.of(context).pop();
                  _showTheForges();
                },
                onUnlock: () async {
                  await _unlockMachine(Machine.local());
                  await step.ask();
                },
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        ),
      );
      if (step.given) return null;
      // The placing dialog follows a token as given on null: a page closed without one says so.
      return step.problem ?? (atOnce ? 'No token was given. Give it when you are ready.' : null);
    } finally {
      step.dispose();
    }
  }

  /// Gives [host] the token [answer] found: the declared one handed on by Porelo, the kept one fed over ssh, or the
  /// secrets file's in a terminal. Answers null once the host took it, or why not.
  Future<String?> _giveTokenFrom(String host, TokenSourceAnswer answer) async {
    final view = _organization?.view;
    final forge = organizationForgeName(view);
    final address = organizationKeptTokenAddress(view);
    final where = forge == 'central forge' ? 'the central forge' : forge;
    final machine = widget.machines.all.where((machine) => machine.hostCard?.name == host).firstOrNull;
    final card = machine?.hostCard;
    if (machine == null || card == null) return 'Connect to $host first.';
    try {
      switch (answer) {
        case TokenSourceAnswer(source: TokenSource.declared, :final declared?):
          try {
            return handedOverWords(host, declared, handedOver: await _organization!.source.handTokenTo(host));
          } on OrganizationRefused catch (refused) {
            return '$host was given no token: ${refused.words}';
          }
        case TokenSourceAnswer(source: TokenSource.kept) when address != null:
          final command = organizationRefreshArguments(
            card: card,
            config: machine.sshConfig,
            environment: widget.machines.tunnels.configEnvironment ?? desk.environment,
            windows: desk.isWindows,
          );
          return tokenGivenWords(host, forge, await _forges.feedKeptToken(address, command));
        case TokenSourceAnswer(source: TokenSource.secretsFile, :final secrets?):
          return await _feedSecrets(host, forge, where, machine, card, secrets);
        default:
          return noTokenWords(host, forge);
      }
    } on HostFilesRefused catch (refused) {
      return refused.message;
    } on FormatException catch (refused) {
      return refused.message;
    } on WorkspaceRefused catch (refused) {
      return refused.words;
    } on ForgeRefused catch (refused) {
      return refused.words;
    } on ProcessException catch (failed) {
      return 'This computer could not run ssh, so $host was given no token: ${failed.message}';
    }
  }

  Future<String?> _feedSecrets(
    String host,
    String forge,
    String where,
    Machine machine,
    HostCardSsh card,
    CentralToken secrets,
  ) async {
    final command = organizationRefreshFeedCommand(
      card: card,
      config: machine.sshConfig,
      token: secrets,
      environment: widget.machines.tunnels.configEnvironment ?? desk.environment,
      windows: desk.isWindows,
    );
    if (!mounted) return null;
    String? lastSaid;
    final end = await runInATerminal(
      context,
      lastLine: (line) => lastSaid = line,
      title: 'Give $host your $forge token, once',
      explanation:
          '$host has no account at $where. For setup it uses your $forge token once to add read-only keys '
          "to the Porelo organization's repository and any waiting projects' central repositories, and to copy those "
          'projects to its own forge. From then on it reads with those keys. It does not keep the token. '
          'The token must be allowed to administer those repositories (Administration: write) and read their contents. '
          '${_centralTokenWords(secrets, host)}',
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
      showCommand: false,
      completed: '$host took the token.',
      answersForTheWindow: true,
    );
    if (end.started && end.code == 0) return null;
    if (!end.started) return '$host was given no token: its terminal could not be opened.';
    final last = lastSaid?.trim() ?? '';
    return '$host did not take the token: ${last.isEmpty ? 'its terminal ended with code ${end.code}' : last}';
  }

  /// What a terminal feeding the central token to [target] will ask of the person.
  String _centralTokenWords(CentralToken token, String target) => token is SecretsFile
      ? 'Type the master password of your secrets file into the terminal. The terminal reads the central forge token '
            'from that file and sends it to $target on its standard input; this window does not see or keep it.'
      : 'The terminal sends the central forge token this instance was started with to $target on its standard input, '
            'and asks nothing.';

  Future<void> _transferOnce(Machine machine, String project, ProjectTransfer direction) async {
    final card = machine.hostCard;
    if (card == null) return;
    final List<String> command;
    final CentralToken? secrets;
    try {
      secrets = centralToken(widget.settings.secretsFile, desk.environment);
      if (secrets == null) return;
      command = projectTransferFeedCommand(
        direction: direction,
        project: project,
        repositories: const [],
        card: card,
        config: machine.sshConfig,
        token: secrets,
        marked: false,
      );
    } on HostFilesRefused catch (refused) {
      _fleet.say(refused.message);
      return;
    } on FormatException catch (refused) {
      _fleet.say(refused.message);
      return;
    }
    if (!mounted) return;
    final push = direction == ProjectTransfer.push;
    await runInATerminal(
      context,
      title: push ? 'Push the approved main of $project' : 'Take the central state of $project',
      explanation: _centralTokenWords(secrets, machine.name),
      machine: machine,
      command: command,
      open: widget.sessions.openTerminal,
      showCommand: false,
      completed: push ? 'The approved main was pushed.' : 'The central state was taken.',
    );
  }

  /// One project's page on [machine]: under My projects, or, opened [from] the machine, what of it is on that machine,
  /// with the host's [progress] where it was read and why not where [notRead] says.
  Widget _projectPage(
    Machine machine,
    ProjectOnScreen project,
    List<Command> commands,
    String? highlight, {
    ShellPlace? from,
    HostProgress? progress,
    String? notRead,
  }) {
    final watched = widget.machines.all.contains(machine);
    return ProjectDetailsPage(
      key: ValueKey('project ${machine.name}/${project.name}'),
      machine: machine,
      machineState: !watched
          ? 'not read'
          : widget.machines.of(machine).reachability == Reachability.connected
          ? 'Connected'
          : widget.machines.of(machine).answered
          ? 'Not connected'
          : 'not read',
      project: project,
      commands: commands,
      onBack: () => widget.shell.goTo(Section.projects),
      onMachine: () => _openPageMachine(machine),
      machinePath: from == null
          ? null
          : [
              ..._machineSectionPath(machine),
              if (from.machineSection case final section?)
                (label: section.label, go: () => _chooseTreePlace(from, false)),
            ],
      onGeneralPage: from == null ? null : () => _openGeneralProject(project.name),
      machineNote: from == null || !_onTheOrganizationsPage(machine) ? null : notRead,
      highlight: highlight,
      onShown: widget.shell.shown,
      details: ProjectHeader(
        project: project,
        muted: widget.notifications.muted.contains(project.name),
        menu: commands,
        showTitle: false,
        onSync: (repository) {
          _openPageProject(machine, project.name);
          unawaited(_syncTheUpstream(repository: repository));
        },
        onBackups: (repository) {
          _openPageProject(machine, project.name);
          unawaited(_showTheBackups(repository: repository));
        },
        onOpens: (repository) {
          _openPageProject(machine, project.name);
          _checkWorkCanStart(repository: repository);
        },
        onReach: (repository) {
          _openPageProject(machine, project.name);
          unawaited(_openEgress(repository: repository));
        },
        onStart: (repository) {
          _openPageProject(machine, project.name);
          unawaited(_startWork(repository: repository));
        },
        homeserver: _homeserverWords(machine, project.name),
        onTheMachine: from == null ? null : _onTheMachine(machine, project, progress: progress, read: notRead == null),
        startUnavailable: watched
            ? StartWork.whyNot(project.project) ?? notAnswering(widget.machines.of(machine))
            : 'This machine is not connected.',
      ),
      jobs: [
        for (final job in widget.templates.forProject(project.name))
          (
            words: '${job.name} ${job.agent} ${job.mode.name}',
            child: TemplateRow(
              job: job,
              highlighted: highlight == 'template.start/${job.project}/${job.name}',
              onShown: widget.shell.shown,
              unavailable: watched && job.startable
                  ? notAnswering(widget.machines.of(machine))
                  : 'This job cannot start here.',
              onPressed: () {
                _openPageProject(machine, project.name);
                unawaited(_startFromTemplate(job));
              },
            ),
          ),
      ],
    );
  }

  /// The project's own page, for all of it: the organization's where it lists the project, else its page under My
  /// projects.
  void _openGeneralProject(String project) {
    final organization = _organization?.view;
    if (organization != null && organization.projects.any((each) => each.name == project)) {
      _chooseTreePlace(const ShellPlace(Section.projects), false);
      setState(() {
        _organizationProjectFrom = const ShellPlace(Section.projects);
        _organizationProject = project;
      });
      return;
    }
    _projectFrom = null;
    setState(() {});
  }

  /// What [machine] holds of each repository of [project], by name: from what the host said where its card names it,
  /// and from the machine's own list of work.
  Map<String, String> _onTheMachine(
    Machine machine,
    ProjectOnScreen project, {
    required HostProgress? progress,
    required bool read,
  }) {
    final fleet = widget.machines.all.contains(machine) ? widget.machines.of(machine) : null;
    // A machine that does not answer now has its last list, which is no word on what runs there now.
    final tasks = fleet != null && fleet.listRead && fleet.reachability == Reachability.connected ? fleet.tasks : null;
    final p = project.project;
    final listed = <String, Repository>{
      for (final each in p.repositoryStates)
        if (!each.own || p.repositoryStates.length == 1) each.name: each,
    };
    final names = listed.keys.toSet();
    if (!_onTheOrganizationsPage(machine)) {
      return {
        for (final each in listed.values)
          each.name: repositoryOnAMachine(project: project.name, listed: each, carried: p.carried, tasks: tasks),
      };
    }
    final card = machine.hostCard!.name;
    final host = _organization?.view?.hosts.where((each) => each.name == card).firstOrNull;
    final carriedAlone = host?.repositories[project.name];
    final said = progress?.of(project.name);
    return {
      for (final name in {
        ...names,
        for (final row in said?.repositories ?? const <HostRepositoryProgress>[]) row.repository,
        ...?carriedAlone,
      })
        name: repositoryOnTheMachine(
          project: project.name,
          repository: name,
          progress: said,
          progressRead: read && progress != null,
          tasks: tasks,
          carriedAlone: carriedAlone,
          listed: listed[name],
        ),
    };
  }

  Widget _machineBody(Machine selected, FleetModel fleet, String? highlight) {
    final machine = widget.shell.itemMachine ?? selected;
    final watched = widget.machines.all.contains(machine);
    final projectName = widget.shell.itemProject ?? fleet.selectedProject?.name;
    final project = projectsOnMachine(
      widget.machines,
      machine,
    ).where((project) => project.name == projectName).firstOrNull;
    // A project's page whose project went - removed, cleared - goes back to the
    // list of projects rather than showing its machine's page under the project's name (walk 9).
    if (widget.shell.section == Section.project && project == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.shell.section == Section.project &&
            (widget.shell.itemProject ?? _fleet.selectedProject?.name) == projectName) {
          widget.shell.goTo(Section.projects);
        }
      });
    }
    if (widget.shell.section == Section.project && project != null) {
      final commands = _pageProjectCommands(machine, project);
      final from = identical(_projectOpenedAt, widget.shell.place) && _projectFrom?.machine?.name == machine.name
          ? _projectFrom
          : null;
      if (from != null && _onTheOrganizationsPage(machine)) {
        return HostProgressReading(
          key: ValueKey('project-on-machine ${machine.name}/${project.name}'),
          organization: _organization!,
          connections: _hostConnections,
          host: machine.hostCard!.name,
          builder: (context, progress, why) =>
              _projectPage(machine, project, commands, highlight, from: from, progress: progress, notRead: why),
        );
      }
      return _projectPage(machine, project, commands, highlight, from: from);
    }
    if (watched) _keepTheVaultButtonTrue(machine, widget.machines.of(machine));
    final onePage = machine.hostCard != null && _organization != null;
    final details = MachineDetailsPage(
      key: ValueKey('machine ${machine.name}'),
      embedded: onePage,
      machine: machine,
      machines: widget.machines,
      commands: watched
          ? [
              for (final command in [
                ..._machineMenu(on: machine),
                ..._commands().where((command) => command.id == 'machine.panic'),
              ])
                command.unless(_itemScopeProblem(command)),
            ]
          : const [],
      highlight: highlight,
      onShown: widget.shell.shown,
      onBack: () => widget.shell.goTo(Section.machines),
      onProject: (project) => _openPageProject(machine, project, from: ShellPlace(Section.machine, machine: machine)),
      projectCommands: (project) => _pageProjectCommands(machine, project),
      tools: watched ? _vaultButtonsFor(machine, widget.machines.of(machine), _toolsFor(machine).vault) : null,
    );
    return onePage
        ? _machineOnePage(
            machine.hostCard!.name,
            work: details,
            machineProjects: machineProjectRows(
              machine: machine,
              machines: widget.machines,
              onProject: (project) =>
                  _openPageProject(machine, project, from: ShellPlace(Section.machine, machine: machine)),
              projectCommands: (project) => _pageProjectCommands(machine, project),
            ),
          )
        : details;
  }

  /// One server's one page, reached from either list: where a person stands, what they do there, and its managing.
  /// Opens *Set up a machine*, with the check where the collection carried here holds one.
  Future<void> _openPrepare({String? machineName}) async {
    final hostCheck = await HostCheckRun().ifCarried();
    if (!mounted) return;
    final keys = SshHostKeys();
    final setup = ServerSetup(
      access: _hostRuns.hostAccess,
      runs: _hostRuns,
      settings: widget.settings,
      hostCheck: hostCheck,
      knownWithAnother: keys.knownWithAnother,
      forgetOldKey: keys.forget,
      // The card key is in the agent, never in a file here: ssh is told to offer that key alone.
      rootLogin: ({required address, required pin, required cardKey}) => tryRootLogin(
        OpenSsh(
          knownHosts: File(pin),
          identity: '',
          agentOnly: true,
          agentPublicKey: cardKey,
          deadline: const Duration(seconds: 30),
        ),
        address,
      ),
      machineName: machineName,
    );
    try {
      await showServerSetupWizard(
        context,
        setup: setup,
        openTerminal: _openServerTerminal,
        token: _hostTokenStep,
        onSignIn: _showTheForges,
        onUnlock: () => unawaited(_unlockMachine(Machine.local())),
      );
    } finally {
      setup.dispose();
    }
  }

  /// The provider's first login, in a terminal on this computer: the person types there, the window never does.
  Future<void> _openServerTerminal(BuildContext context, List<String> command) async {
    await runInATerminal(
      context,
      title: 'A terminal on the server',
      explanation:
          'This logs in with the account your provider gave you, trusting only the SSH host key you compared. Paste '
          'the line there, and close the terminal once it is done.',
      machine: Machine.local(),
      command: command,
      open: widget.sessions.openTerminal,
    );
  }

  /// Prepares the machine named, where this computer offers preparing at all.
  void Function(String)? get _prepareThisMachine =>
      _commands().any((command) => command.id == 'host.prepare' && command.visible)
      ? (host) => unawaited(_openPrepare(machineName: host))
      : null;

  /// The preparation running on this computer for the organization's machine [host], as *My machines* lists it.
  HostPreparation? _preparingFor(String host) =>
      _hostRuns.preparing.where((run) => run.record.hostName == host).firstOrNull;

  ShellPlace _organizationDetailOrigin(ShellPlace? from, ShellPlace fallback) {
    if (from == null) return fallback;
    // An organization removed or replaced since opening cannot remain an ancestor.
    if (from.section == Section.organization && from.organization != _organization?.view?.name) return fallback;
    return from;
  }

  List<LeafPathStep> _organizationDetailPath(ShellPlace? from, ShellPlace fallback, VoidCallback back) {
    final origin = _organizationDetailOrigin(from, fallback);
    if (origin.section != Section.organization) return [(label: origin.section.label, go: back)];
    return [
      (label: 'Organizations', go: () => _chooseTreePlace(const ShellPlace(Section.organizations), true)),
      (
        label: origin.organization ?? 'Organization',
        go: () => _chooseTreePlace(ShellPlace(Section.organization, organization: origin.organization), true),
      ),
      if (origin.organizationSection case final section?) (label: section.label, go: back),
    ];
  }

  void _backFromOrganizationProject() {
    final origin = _organizationDetailOrigin(_organizationProjectFrom, const ShellPlace(Section.projects));
    _chooseTreePlace(origin, false);
  }

  void _backFromOrganizationHost() {
    final origin = _organizationDetailOrigin(_organizationHostFrom, const ShellPlace(Section.machines));
    _chooseTreePlace(origin, false);
  }

  Widget _machineOnePage(
    String host, {
    Widget? work,
    List<({String name, Widget row})>? machineProjects,
    bool onlyAdmins = false,
    List<LeafPathStep>? path,
  }) {
    final machine = widget.machines.all.where((machine) => machine.hostCard?.name == host).firstOrNull;
    return ListenableBuilder(
      // Read again as a preparation starts and ends, so the page offers its protocol, not a second start; and as the
      // machine answers, for its head.
      listenable: Listenable.merge([_hostRuns, if (machine != null) widget.machines.of(machine)]),
      builder: (context, _) => OrganizationHostPage(
        onlyAdmins: onlyAdmins,
        version: machine == null ? null : widget.machines.of(machine).info?.version,
        lastAnswered: machine == null ? null : widget.machines.of(machine).lastAnswered,
        path:
            path ??
            _organizationDetailPath(
              _organizationHostFrom,
              const ShellPlace(Section.machines),
              _backFromOrganizationHost,
            ),
        onPrepare: _prepareThisMachine,
        preparing: _preparingFor,
        onProtocol: (run) => unawaited(_openHostRun(run)),
        key: ValueKey(host),
        organization: _organization!,
        connections: _hostConnections,
        onGiveToken: _giveHostToken,
        onStartWork: (host, project) async {
          final machine = widget.machines.all.where((machine) => machine.hostCard?.name == host).firstOrNull;
          if (machine == null) return 'This window does not have $host among its machines, so it cannot start there.';
          widget.machines.select(machine);
          if (project == null) {
            // The organization's view may be older than what the machine lists: Default is not taken unasked.
            await _fleet.refresh(quietly: true);
            if (!mounted) return null;
            final others = _fleet.projects.where(
              (each) => each.name != defaultProject && (each.canBeActedOn || each.project.carried),
            );
            if (others.isNotEmpty) {
              unawaited(_newWork(on: machine));
              return null;
            }
            // Its output and its session are shown under Work, and not on this page.
            widget.shell.goTo(Section.work);
            unawaited(_startInDefault());
            return null;
          }
          return _startFromTheMachinePage(host, project);
        },
        keys: _keys,
        refresh: _organizationPageRefresh,
        host: host,
        work: work,
        machineProjects: machineProjects,
        onBack: _backFromOrganizationHost,
      ),
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

  /// What is open over the frame, or null when nothing is.
  ///
  /// Resolved rather than read straight off the model, because what a view points at can go away
  /// underneath it: work that stopped existing, an operation this session never had.
  Widget? _opened({Machine? on}) {
    final opened = widget.shell.opened;
    if (opened is NothingOpened) return null;
    final machine = on ?? widget.machines.current;
    if (!widget.machines.all.contains(machine) &&
        opened is! OperationsOpened &&
        opened is! OperationOpened &&
        opened is! LogOpened) {
      return null;
    }
    late final fleet = widget.machines.of(machine);
    switch (opened) {
      case NothingOpened():
        return null;
      case WorkOpened():
        final task = fleet.selectedTask;
        if (task == null) return null;
        return WorkDetail(
          task: task,
          repository: fleet.projectOf(task)?.repositoryOf(task),
          held: widget.held,
          handing: _handing,
          handIns: _handIns,
          onClose: widget.shell.close,
        );
      case BackupsOpened():
        return BackupsView(
          backups: widget.backups,
          onConsider: (backup) => widget.backups.consider(fleet.backend, backup),
          onConsiderRestoring: (backup) => widget.backups.considerRestoring(fleet.backend, backup),
          onRestore: ({required force}) => _restoreTheMirror(force: force, on: machine),
          onRemove: () => _removeTheBackup(on: machine),
          onLetItBe: widget.backups.letItBe,
          onClose: widget.shell.close,
        );
      case EgressOpened():
        return EgressView(egress: widget.egress, onClose: widget.shell.close);
      case GateOpened():
        return GateView(
          gate: widget.gate,
          focusNode: _openedFocus,
          onOpen: (push) => unawaited(_look(push, on: machine)),
          onClose: widget.shell.close,
        );
      case ReviewOpened():
        final machine = widget.machines.current;
        return ReviewView(
          gate: widget.gate,
          onBack: widget.shell.openGate,
          onClose: widget.shell.close,
          onApprove: () => unawaited(_approve(on: machine)),
          onReject: () => unawaited(_reject(on: machine)),
          login: machine.needsATunnel ? machine.host : null,
          sshConfig: reviewFetchConfig(machine, windows: desk.isWindows),
          machine: machine.name,
          onRefreshKeys: () => unawaited(widget.gate.readKeys(fleet.backend)),
          onTryKey: (key) => unawaited(widget.gate.tryKey(fleet.backend, key)),
          onKeepKey: (key) => unawaited(_keepKey(key, on: machine)),
          onWithoutLineEndings: (without) => unawaited(widget.gate.showWithoutLineEndings(fleet.backend, without)),
          // Offered only where a terminal opens on the machine from here.
          onKeyTerminal: onTheMachine(machine, const <String>['porelo'], terminal: true) == null
              ? null
              : () => unawaited(_refusedKeyInATerminal(on: machine)),
        );
      case LogOpened(:final task, :final log, :final formatted):
        final tail = widget.logs.find(task, log, formatted: formatted);
        if (tail == null) return null;
        return LogView(tail: tail, logs: widget.logs, onClose: widget.shell.close);
      case OperationsOpened():
        return OperationsList(
          operations: widget.operations,
          machine: machine.name,
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
          signIn: _signInsAfterAFailedStart[id] == null
              ? null
              : SignInPanel(signingIn: _signInsAfterAFailedStart[id]!, keyed: 'operation'),
          onBack: widget.shell.openOperations,
          onClose: widget.shell.close,
        );
    }
  }

  /// Opens a session on [task] in its tab under *Running*, the one place a terminal is, leaving the one
  /// that was open: **one at a time**.
  void _openSession(Task task, {Machine? on}) {
    _workView.showTab(
      WorkView.placeOf((on ?? widget.machines.current).name, task.name),
      byHand: task.mode == Mode.unattended,
    );
    widget.shell.goTo(Section.work);
    widget.shell.close();
  }

  @override
  void dispose() {
    widget.machines.pauseAutomaticRetries();
    widget.shell.removeListener(_followTreeTool);
    widget.shell.removeListener(_checkOrganizationPlace);
    _organization?.removeListener(_checkOrganizationPlace);
    widget.machines.removeListener(_machineChanged);
    for (final tools in _machineTools.values) {
      _releaseTools(tools);
    }
    _machineTools.clear();
    _providerCards.clear();
    _destinationCards.clear();
    _sectionRetries.clear();
    for (final filter in _sectionFilters.values) {
      filter.dispose();
    }
    _sectionFilters.clear();
    _sectionReadAt.clear();
    _vaultAskedFor.clear();
    _menuFocus.dispose();
    final source = widget.organizationSource;
    if (source is PoreloOrganizationSource) {
      source.prepareForgeWrite = null;
      source.confirmForgeHost = null;
    }
    if (widget.hostConnections == null) _hostConnections?.dispose();
    _organization?.removeListener(_readStandings);
    _organization?.dispose();
    _transfers.dispose();
    for (final run in _runs.values) {
      run.dispose();
    }
    for (final signIn in _signInsAfterAFailedStart.values) {
      signIn.dispose();
    }
    for (final check in _waitsForAFailedStart.values) {
      widget.operations.removeListener(check);
    }
    _waitsForAFailedStart.clear();
    widget.shell.removeListener(_leaveTheSignInsWithTheirView);
    widget.shell.removeListener(_moveKeyboard);
    widget.sessions.removeListener(_moveKeyboard);
    widget.shell.removeListener(_leaveTheSessionWithItsPage);
    _workView.removeListener(_leaveTheSessionWithItsPage);
    _workView.removeListener(_moveKeyboard);
    widget.settings.removeListener(_keepRefreshing);
    _refreshing?.cancel();
    _leaving.dispose();
    _homeservers.removeListener(_homeserversChanged);
    widget.hostAccess?.removeListener(_homeserversChanged);
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
    _standings.removeListener(_homeserversChanged);
    _standings.dispose();
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

/// What is said above [agent]'s sign-in on [machine], from the flow its definition names.
///
/// A missing or unknown flow promises no way of its own: it says what every sign-in has in common and
/// where the agent documents its own.
String signInExplanation(Agent agent, String machine) {
  const stored = 'What the sign-in gives goes into the vault there, and never through this program.';
  final opening =
      'This runs the agent’s own sign-in on $machine. It shows a link: open it in your browser and sign in.';
  return switch (agent.loginFlow) {
    LoginFlow.pasteCode => '$opening Paste the code shown in your browser into the terminal below. $stored',
    LoginFlow.deviceCode => '$opening Confirm on the device page the code the terminal below shows. $stored',
    LoginFlow.loopback => '$opening The page then hands the answer back by itself. $stored',
    null =>
      '$opening Then follow what the terminal below says.'
          '${agent.loginDocumentation.isEmpty ? '' : ' The agent describes its sign-in at ${agent.loginDocumentation}.'} $stored',
  };
}

/// Stands behind the transfer guards only: a transfer runs in the person's terminal, never through this source.
class _TerminalOnly implements CentralTransferSource {
  @override
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String line)? onLine,
  }) => throw const RemoteNotStarted();
}
