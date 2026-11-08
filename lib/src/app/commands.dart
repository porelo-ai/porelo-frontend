import 'dart:async';

import 'package:porelo_host/porelo_host.dart' show ProjectTransfer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_model.dart';
import 'host_runs.dart';
import 'host_access.dart';
import 'desk.dart';
import 'product.dart';
import 'hand_in.dart';
import 'machines.dart';
import 'narrowing.dart';
import 'notifications.dart';
import 'operations.dart';
import 'session.dart';
import 'settings.dart';
import 'shell_model.dart';
import 'start_agents.dart';
import 'start_work.dart';
import 'task_certifying.dart';
import 'templates.dart';
import 'vault.dart';
import 'project_transfers.dart';
import 'central_reviews.dart';
import 'forge.dart';
import 'links.dart';
import 'organization_source.dart';
import 'widening.dart';

/// Where an action lives on screen, so the finder can go there and show it.
enum Home {
  /// Run where it was chosen: no single place on screen is its own.
  none,

  /// The title bar at the top of the window.
  appBar,

  /// A button of its own in the machine's title.
  machineTitle,

  /// The menu in the machine's title.
  machineMenu,

  /// The menu on the selected project's card.
  projectMenu,

  /// The start button and menu on a repository's row on its project page.
  repositoryRow,

  /// The tile that starts work.
  startTile,

  /// A named job's own tile.
  templateTile,

  /// The menu on the selected work's tile.
  tileMenu,

  /// An action on a machine or a server in preparation.
  machineRow,

  /// Navigation from a project row on the Projects page.
  projectRow,

  /// An action on a forge row.
  forgeRow,

  /// An action in a row or a section of the organization's page.
  organizationRow,

  /// An action on a Needs you row.
  attentionRow,

  /// An action in the project's Messages dialog.
  messagesDialog,

  /// The machine's status line.
  statusLine,

  /// Actions in the view open over the frame.
  openedView,
}

/// One action on the organization's page, which offers it only to the person whose role it belongs to.
Command organizationCommand({
  required String id,
  required String label,
  required VoidCallback run,
  String? unavailable,
  bool danger = false,
}) => Command(
  id: 'organization.$id',
  label: label,
  group: 'Organization',
  home: Home.organizationRow,
  run: run,
  unavailable: unavailable,
  danger: danger,
);

/// Opens [host]'s forge through its connection using the address its card supplies; [hasForge] is what the
/// organization says of it, known before any connection.
Command openHostForgeCommand({required String host, required HostConnections? connections, bool hasForge = true}) {
  String? whyUnavailable() {
    if (!hasForge) return 'This host has no forge.';
    if (!(connections?.up(host) ?? false)) {
      return 'Connect first: the forge is reached through the connection';
    }
    return connections?.forgeUrl(host) == null ? 'This host has no forge.' : null;
  }

  return Command(
    id: 'organization.openForge/$host',
    label: 'Open its forge',
    group: 'Organization',
    home: Home.organizationRow,
    unavailableNow: whyUnavailable,
    run: () {
      if (connections?.forgeUrl(host) case final address?) unawaited(openLink(Uri.parse(address)));
    },
  );
}

/// Leaves a view onto work without interrupting the work itself.
Command leaveWorkCommand(VoidCallback leave, {String? unavailable}) => Command(
  id: 'work.leave',
  label: 'Leave',
  group: 'Work',
  home: Home.openedView,
  run: leave,
  unavailable: unavailable,
);

/// Opens the watched task's start form for review before another run.
Command restartRunCommand({required Task? task, required VoidCallback open, String? unavailable}) => Command(
  id: 'work.restartRun',
  label: task?.inboxWaiting == null ? 'Start again' : 'Start again, ${task!.inboxWaiting} messages wait',
  group: 'Work',
  home: Home.openedView,
  run: open,
  unavailable:
      unavailable ??
      (task == null
          ? 'the task has not been reported'
          : task.activity.name != 'ENDED'
          ? 'the agent has not ended'
          : task.inboxWaiting == null
          ? 'the machine has not reported waiting messages'
          : task.inboxWaiting! <= 0
          ? 'no messages wait'
          : null),
);

/// One action in the product, by name.
///
/// Everything the interface can do is declared here rather than only wired to a widget, for two
/// reasons that are the same reason: the command finder can then name an action belonging to a
/// screen that is not open, and a keyboard shortcut cannot drift from the menu entry beside it.
@immutable
class Command {
  /// Constructor taking everything the finder and the keyboard need.
  const Command({
    required this.id,
    required this.label,
    required this.group,
    required this.run,
    this.shortcut,
    String? unavailable,
    this.unavailableNow,
    this.home = Home.none,
    this.checked,
    this.hidden = false,
    this.danger = false,
    // The public named argument remains compatible with existing const commands.
    // ignore: prefer_initializing_formals
  }) : _unavailable = unavailable;

  /// Stable identifier, used to route a keystroke to this command.
  final String id;

  /// What it is called, in the words the person would search for.
  final String label;

  /// What it belongs to, so a long list stays readable.
  final String group;

  /// Whether this person is not offered it at all, as they hold nothing it could do.
  final bool hidden;

  /// Whether it takes something away, which its entry in a menu shows by its color.
  final bool danger;

  /// Whether this person is offered it.
  bool get visible => !hidden;

  /// What it does.
  final VoidCallback run;

  /// The key that runs it, when it has one.
  final SingleActivator? shortcut;

  /// Why it cannot be run now, or null when it can.
  ///
  /// An unavailable command is still listed. Hiding it would make the finder answer "there is
  /// no such action" when the truth is "not yet, and here is what is missing".
  String? get unavailable => unavailableNow?.call() ?? _unavailable;
  final String? _unavailable;

  /// Rechecks an action whose controller can change after this command is built.
  final String? Function()? unavailableNow;

  /// Where it lives on screen.
  final Home home;

  /// For one of several choices, whether it is the one made; null for an action.
  final bool? checked;

  /// Whether it can be run now.
  bool get available => unavailable == null;

  /// The same command, unavailable for [reason] unless it already is for another.
  Command unless(String? reason) => reason == null || unavailable != null
      ? this
      : Command(
          id: id,
          hidden: hidden,
          label: label,
          group: group,
          shortcut: shortcut,
          unavailable: reason,
          unavailableNow: unavailableNow,
          home: home,
          checked: checked,
          run: run,
        );

  /// The same command, doing [first] before it runs.
  Command after(VoidCallback first) => Command(
    id: id,
    hidden: hidden,
    label: label,
    group: group,
    shortcut: shortcut,
    unavailable: _unavailable,
    unavailableNow: unavailableNow,
    home: home,
    checked: checked,
    run: () {
      first();
      run();
    },
  );
}

/// What can be done to one piece of work, wherever it is offered.
///
/// One builder for the row's own menu and for the finder, so an action cannot be offered in one
/// place and forgotten in the other. Actions that no backend method can perform stay in the list
/// **named and unavailable, with the reason** — an action that simply is not there reads as one
/// nobody thought of, rather than as one the daemon cannot do yet.
List<Command> workCommands({
  required Task? task,
  required FleetModel fleet,
  required Machine machine,
  required void Function(Task task) askToRemove,
  required void Function(Task task) askWhichLog,
  required void Function(Task task) openSession,
  required void Function(Task task) continueTheWork,
  required void Function(Task task) recreate,
  required void Function(Task task) nameTheWork,
  required void Function(Task task) widenTheWork,
  required void Function(Task task) enforceOnTheWork,
  required void Function(Task task) narrowTheWork,
  void Function(Task task)? talkForTheWork,
  void Function(Task task)? tellTheWork,
  void Function(Task task)? handInTo,
  void Function(Task task)? takeBackFrom,
  void Function(Task task)? refreshFromItsSource,
  VoidCallback? unlockTheVault,
  void Function(Task task)? certifyAgain,
}) {
  const nothingSelected = 'no work is selected';
  final offline = notAnswering(fleet);
  return <Command>[
    Command(
      id: 'work.resume',
      label: task?.startAction == StartAction.create ? 'Start it' : 'Start it again',
      group: 'Work',
      home: Home.tileMenu,
      run: () => fleet.startAgain(task!),
      // The machine says beforehand what Start would do, so a refusal is never found by pressing.
      unavailable: task == null
          ? nothingSelected
          : whyNotStart(task) ??
                (task.task.isEmpty
                    ? 'the machine does not say its name within the project'
                    : fleet.projectNameOf(task) == null
                    ? 'nothing here knows where its project file is'
                    : null),
    ),
    // Offered where the refusal is, rather than reported as a failure: unlocking is the one thing
    // that helps a task whose tokens are in a locked vault.
    if (task != null && task.startAction == StartAction.needsVault)
      Command(
        id: 'work.unlock',
        label: 'Unlock the vault, so this can start',
        group: 'Work',
        home: Home.tileMenu,
        run: () => unlockTheVault?.call(),
        unavailable: unlockTheVault == null ? 'this machine cannot be unlocked from here' : offline,
      ),
    Command(
      id: 'work.stop',
      label: 'Stop it, keeping its workspace',
      group: 'Work',
      home: Home.tileMenu,
      run: () => fleet.stopWork(task!.name),
      unavailable: task == null
          ? nothingSelected
          : task.running
          ? null
          : 'it is not running',
    ),
    Command(
      id: 'work.session',
      label: 'Work in it by hand',
      group: 'Work',
      home: Home.tileMenu,
      run: () => openSession(task!),
      // **Both reasons are answerable from the task itself**, so this is offered as unavailable
      // with the reason rather than offered and refused.
      unavailable: task == null ? nothingSelected : Sessions.whyNot(task, machine)?.words,
    ),
    Command(
      id: 'work.log',
      label: 'Read one of its logs',
      group: 'Work',
      home: Home.tileMenu,
      run: () => askWhichLog(task!),
      unavailable: task == null ? nothingSelected : null,
    ),
    Command(
      id: 'work.continue',
      label: 'Continue this work with a new prompt',
      group: 'Work',
      home: Home.tileMenu,
      run: () => continueTheWork(task!),
      // Three separate reasons, each said rather than collapsed into "not now".
      unavailable: StartWork.whyNotContinue(task),
    ),
    Command(
      id: 'work.widen',
      label: 'Let this work reach something new',
      group: 'Work',
      home: Home.tileMenu,
      run: () => widenTheWork(task!),
      // Both refusals the daemon would give are knowable here, so they are said, not discovered.
      unavailable: Widening.whyNot(task),
    ),
    Command(
      id: 'work.narrow',
      label: 'Take something back from this work',
      group: 'Work',
      home: Home.tileMenu,
      run: () => narrowTheWork(task!),
      unavailable: Narrowing.whyNot(task),
    ),
    Command(
      id: 'work.enforcement',
      label: 'Change what this work does with a blocked connection',
      group: 'Work',
      home: Home.tileMenu,
      run: () => enforceOnTheWork(task!),
      unavailable: task == null
          ? nothingSelected
          : !task.running
          ? 'it is not running, and there is nothing to change'
          : null,
    ),
    Command(
      id: 'work.talk',
      label: "Hold its project's messages to a peer",
      group: 'Work',
      home: Home.tileMenu,
      run: () => talkForTheWork?.call(task!),
      unavailable: task == null
          ? nothingSelected
          : task.project.isEmpty
          ? 'nothing recorded which project it belongs to, and its project says whom it may talk to'
          : talkForTheWork == null
          ? 'not offered here'
          : null,
    ),
    // Straight into its inbox, where its agent reads: a person's own words, which never leave the
    // machine and so are neither signed nor filtered.
    Command(
      id: 'work.tell',
      label: 'Write to its agent',
      group: 'Work',
      home: Home.tileMenu,
      run: () => tellTheWork?.call(task!),
      unavailable: task == null
          ? nothingSelected
          : tellTheWork == null
          ? 'not offered here'
          : null,
    ),
    Command(
      id: 'work.label',
      label: task != null && task.label.isNotEmpty
          ? 'Change what this work reads as'
          : 'Give this work something to read by',
      group: 'Work',
      home: Home.tileMenu,
      run: () => nameTheWork(task!),
      unavailable: task == null ? nothingSelected : null,
    ),
    Command(
      id: 'work.certifyAgain',
      label: 'Certify it for another week',
      group: 'Work',
      home: Home.tileMenu,
      run: () => certifyAgain!(task!),
      unavailable: certifyAgain == null
          ? 'not offered here'
          : task == null
          ? nothingSelected
          : machine.needsATunnel || (machine.host.isEmpty && machine.socketPath == Backend.local().socketPath)
          ? whyNoCertifyAgain(task)
          : 'the command line reaches this computer or a host over ssh, and not this machine',
    ),
    Command(
      id: 'work.handIn',
      label: 'Hand it a file from this computer',
      group: 'Work',
      home: Home.tileMenu,
      run: () => handInTo!(task!),
      unavailable: handInTo == null ? 'not offered here' : HandingIn.whyNot(task),
    ),
    Command(
      id: 'work.takeBack',
      label: 'Take back a file it was handed',
      group: 'Work',
      home: Home.tileMenu,
      run: () => takeBackFrom!(task!),
      unavailable: takeBackFrom == null ? 'not offered here' : HandingIn.whyNotTakeBack(task),
    ),
    // What moved in the checkout or the remote it works from, brought to it without stopping it.
    Command(
      id: 'work.refresh',
      label: 'Bring it up to its source',
      group: 'Work',
      home: Home.tileMenu,
      run: () => refreshFromItsSource!(task!),
      unavailable: refreshFromItsSource == null
          ? 'not offered here'
          : task == null
          ? nothingSelected
          : null,
    ),
    Command(
      id: 'work.recreate',
      label: 'Recreate it, so it picks up a newly built environment',
      group: 'Work',
      home: Home.tileMenu,
      run: () => recreate(task!),
      // A stopped task is recreated as readily as a running one, and that is often when it is.
      unavailable: task == null ? nothingSelected : null,
    ),
    Command(
      id: 'work.remove',
      label: 'Remove it',
      group: 'Work',
      home: Home.tileMenu,
      run: () => askToRemove(task!),
      unavailable: task == null ? nothingSelected : null,
    ),
    Command(
      id: 'work.rename',
      label: 'Rename it',
      group: 'Work',
      home: Home.tileMenu,
      run: () {},
      unavailable: 'the backend has no method for renaming work',
    ),
  ].map((command) => command.unless(offline)).toList();
}

/// Unlocks the named machine using the same terminal path as a work tile.
Command unlockWaitingMessages(Machine machine, FleetModel fleet, VoidCallback? unlock) => Command(
  id: 'messages.unlock/${machine.name}',
  label: 'Unlock the vault on ${machine.name}',
  group: 'Messages',
  home: Home.attentionRow,
  run: () => unlock?.call(),
  unavailable: unlock == null ? 'this machine cannot be unlocked from here' : notAnswering(fleet),
);

/// Opens the removal preview for one held project on its row's machine; [whyNoRemoval] is why it is not offered.
Command removeWaitingProject(
  Machine machine,
  FleetModel fleet,
  Project project,
  VoidCallback? preview, {
  required String? whyNoRemoval,
}) => Command(
  id: 'messages.removeProject/${machine.name}/${project.name}',
  label: 'Remove ${project.name}…',
  group: 'Messages',
  home: Home.attentionRow,
  run: () => preview?.call(),
  unavailable: project.name == defaultProject
      ? 'the Default project is always there'
      : preview == null
      ? 'not from here'
      : whyNoRemoval ?? notAnswering(fleet),
);

/// Repeats the read that listed held messages, on that row's machine.
Command askForHeldMessages(Machine machine, FleetModel fleet) => Command(
  id: 'messages.ask/${machine.name}',
  label: 'Ask again',
  group: 'Messages',
  home: Home.attentionRow,
  run: () => unawaited(fleet.mailboxes.refresh()),
  unavailable: notAnswering(fleet),
);

/// Reconnects now instead of waiting for the machine's next automatic attempt.
Command retrySilentMachine(Machine machine, FleetModel fleet) => Command(
  id: 'machine.retry/${machine.name}',
  label: 'Try again now',
  group: 'Machines',
  home: Home.attentionRow,
  run: () => unawaited(fleet.connect()),
  unavailable: fleet.reachability == Reachability.connecting ? 'the machine is still connecting' : null,
);

/// Why nothing that needs [fleet]'s machine can be done now, or null while it answers.
String? notAnswering(FleetModel fleet) =>
    fleet.reachability == Reachability.connected ? null : 'the machine is not answering';

/// Starts work in the named repository, shared by its row's button and menu item.
Command repositoryStartCommand({
  required String repository,
  required void Function(String)? onStart,
  String? unavailable,
}) => Command(
  id: 'start-in-$repository',
  label: 'Start work in $repository',
  group: 'Work',
  home: Home.repositoryRow,
  unavailable: unavailable ?? (onStart == null ? 'work cannot start in this project' : null),
  run: () => onStart?.call(repository),
);

/// Why `Start` would refuse [task], in words, or null when it would start it.
String? whyNotStart(Task task) {
  final detail = task.startDetail;
  return switch (task.startAction) {
    StartAction.create || StartAction.resume => null,
    StartAction.running => 'it is already running',
    StartAction.needsVault => 'the vault is locked; unlock it and this can start',
    StartAction.supersededName =>
      'its name is from before one container per task, so it can '
          'only be removed${detail.isEmpty ? '' : ' (it belonged to $detail)'}',
    StartAction.notReady => detail.isEmpty ? 'its project is not ready' : 'its project is not ready: $detail',
    // The machine's own words carry the recovery, which is the one thing worth reading here.
    StartAction.predatesRestart =>
      detail.isEmpty ? 'it was started before this machine restarted, so it can only be recovered and removed' : detail,
    // A daemon too old to say, or a value this build does not know: the runtime's answer decides.
    _ => task.running ? 'it is already running' : null,
  };
}

/// What one project can be told to do, on its card and in the finder.
///
/// Judged for [project] itself, so a card that is not the selected one offers what is true of it.
List<Command> projectCommands({
  required ProjectOnScreen? project,
  required FleetModel fleet,
  Settings? settings,
  HostRuns? hostRuns,
  required Notifications notifications,
  required VoidCallback openTheGate,
  required VoidCallback openEgress,
  required VoidCallback prepareTheProject,
  required VoidCallback syncTheUpstream,
  required VoidCallback showTheBackups,
  required VoidCallback checkWorkCanStart,
  required VoidCallback removeWhatWasBuilt,
  required String? whyNoRemoval,
  VoidCallback? clearTheProject,
  VoidCallback? showTheMessages,
  VoidCallback? openItsForge,
  String? itsForgeIsMissing,
  VoidCallback? showTheDefault,
  VoidCallback? startTheAgents,
}) {
  const nothing = 'no project selected';
  // default's settings are Porelo's own and fixed: nothing here changes what it may reach.
  final isDefault = project?.name == defaultProject;
  final noFile = project == null
      ? nothing
      : project.canBeActedOn
      ? null
      : project.project.carried
      ? '${project.name} is carried by this machine and not taken here yet: starting work takes it'
      : '${project.name} is not on this machine';
  return <Command>[
    // The long-running agents of the project's repositories, each with the agent its project.yml names.
    Command(
      id: 'project.startAgents',
      label: 'Start an agent for each repository…',
      group: 'Project',
      home: Home.projectMenu,
      run: startTheAgents ?? () {},
      unavailable: project?.project.carried == true
          ? (startTheAgents == null ? 'not offered here' : null)
          : noFile ?? (startTheAgents == null ? 'not offered here' : StartAgents.whyNot(project!.project)),
    ),
    Command(
      id: 'gate.open',
      label: 'Review what is waiting at the gate',
      group: 'Project',
      home: Home.projectMenu,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyG, control: true),
      run: openTheGate,
      unavailable: noFile,
    ),
    Command(
      id: 'egress.open',
      label: 'What this project may reach',
      group: 'Project',
      home: Home.projectMenu,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyE, control: true),
      run: openEgress,
      unavailable:
          noFile ??
          (isDefault
              ? 'default keeps Porelo’s own settings, which cannot be changed'
              : project!.project.securityClass == 'offline'
              // An offline project declares no egress at all, and the daemon refuses it.
              ? 'an offline project declares no egress at all'
              : null),
    ),
    Command(
      id: 'project.prepare',
      label: 'Build the environment for this project',
      group: 'Project',
      home: Home.projectMenu,
      run: prepareTheProject,
      // `Prepare` takes the project file, unlike removing what was built, which takes the name.
      unavailable: noFile,
    ),
    Command(
      id: 'project.sync',
      label: 'Ask the upstream how far behind this project is',
      group: 'Project',
      home: Home.projectMenu,
      run: syncTheUpstream,
      unavailable: project == null ? nothing : (project.project.carried ? noFile : null),
    ),
    // Only where there is a conversation: a project that names a peer on a transport of its own.
    Command(
      id: 'project.messages',
      label: 'Messages and the project’s room',
      group: 'Project',
      home: Home.projectMenu,
      run: showTheMessages ?? () {},
      unavailable: project == null
          ? nothing
          : showTheMessages == null
          ? 'not offered here'
          : project.project.messages == null
          ? '${project.name} has no conversation: none of its peers is reached through a transport of its own'
          : null,
    ),
    // The tools for after a project is set up, kept out of the way of setting it up: its keys at
    // the forge, the machines it trusts, changes waiting at this machine, and stopping work here.
    Command(
      id: 'project.forge',
      label: 'Its machines and keys at its forge',
      group: 'Project',
      home: Home.projectMenu,
      run: openItsForge ?? () {},
      unavailable: project == null
          ? nothing
          : openItsForge == null
          ? 'not offered here'
          : itsForgeIsMissing,
    ),
    // The repositories worked on in the Default project: added by address or picked at a forge, and
    // taken out again once a project names them.
    Command(
      id: 'project.default',
      label: 'Repositories of the Default project',
      group: 'Project',
      home: project?.name == defaultProject ? Home.openedView : Home.projectMenu,
      run: showTheDefault ?? () {},
      unavailable: project == null
          ? nothing
          : showTheDefault == null
          ? 'not offered here'
          : project.name != defaultProject
          ? 'only the Default project holds such repositories'
          : null,
    ),
    Command(
      id: 'project.backups',
      label: 'Show what has been backed up here',
      group: 'Project',
      home: Home.projectMenu,
      run: showTheBackups,
      unavailable: project == null ? nothing : (project.project.carried ? noFile : null),
    ),
    Command(
      id: 'work.check',
      // `Start(dryRun:)` reports what the project file opens and returns; it is no rehearsal.
      label: 'Show what this project would open, creating nothing',
      group: 'Project',
      home: Home.projectMenu,
      run: checkWorkCanStart,
      unavailable: fleet.reachability != Reachability.connected ? 'the machine is not answering' : noFile,
    ),
    Command(
      id: 'notifications.mute',
      label: project != null && notifications.mutedFor(project.name)
          ? 'Tell me about ${project.name} again'
          : 'Stop telling me about this project',
      group: 'Project',
      home: Home.projectMenu,
      run: () => notifications.setMuted(project!.name, muted: !notifications.mutedFor(project.name)),
      unavailable: project == null ? nothing : null,
    ),
    // Everything Porelo put on the machine and at the forge for the project, in one step (walk 8).
    Command(
      id: 'project.clear',
      label: 'Clear this project from the machine…',
      group: 'Project',
      home: Home.projectMenu,
      run: clearTheProject ?? () {},
      unavailable: project == null
          ? nothing
          : project.project.carried
          ? noFile
          : clearTheProject == null
          ? 'not from here'
          : project.name == defaultProject
          ? 'the Default project is always there'
          : null,
    ),
    Command(
      id: 'project.delete',
      label: 'Remove this project',
      group: 'Project',
      home: Home.projectMenu,
      run: removeWhatWasBuilt,
      // **Takes the name, not the file**, so a project whose file is gone can still be cleared.
      unavailable: project == null
          ? nothing
          : project.project.carried
          ? noFile
          : project.name == defaultProject
          ? 'the Default project is always there'
          : whyNoRemoval,
    ),
  ].map((command) => command.unless(notAnswering(fleet))).toList();
}

/// Opens server preparation from the Machines page.
Command prepareServerCommand({FutureOr<void> Function()? open, HostAccess? access}) => Command(
  id: 'host.prepare',
  hidden: access?.offersPreparing == false,
  label: 'Set up a machine…',
  group: 'Machines',
  home: Home.machineRow,
  run: () {
    if (access == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
    unawaited(access.prepare(() async => open?.call()));
  },
  unavailable: access == null
      ? 'The verified Machine Admins are unavailable.'
      : access.unavailable() ?? (open == null ? 'server preparation is unavailable here' : null),
);

/// The host's confirmed rental lifecycle.
List<Command> hostMachineCommands({
  required Machine machine,
  required Settings settings,
  HostRuns? hostRuns,
  required VoidCallback takeDown,
}) => [
  if (machine.kind == 'host') ...[
    Command(
      id: 'machine.takeDown',
      label: settings.hostUp(machine.hostProject)?.isRental == true
          ? 'Return this rental…'
          : 'Take Porelo off this machine…',
      group: 'Machine',
      home: Home.machineMenu,
      run: takeDown,
      unavailable:
          _setupAgainUnavailable(hostRuns, machine.hostProject) ??
          hostRuns?.hostAccess?.whyNotTakeDown(settings.hostUp(machine.hostProject)?.hostName ?? machine.hostProject) ??
          (settings.hostUp(machine.hostProject) == null ? 'nothing was kept from putting it on a server' : null),
    ),
  ],
];

/// Removes an account from its room after confirmation on the member's own row.
Command removeMessageMemberCommand(
  String person, {
  required bool supported,
  required bool busy,
  required VoidCallback run,
}) => Command(
  id: 'member-remove $person',
  label: 'Remove',
  group: 'Messages',
  home: Home.messagesDialog,
  unavailable: !supported
      ? 'this Porelo cannot remove an account from the room yet'
      : busy
      ? 'the machine is still answering'
      : null,
  run: run,
);

/// Lets a named person join the room after an explicit request.
Command joinMessagesCommand({required String person, required bool busy, required VoidCallback run}) => Command(
  id: 'join-it',
  label: 'Join',
  group: 'Messages',
  home: Home.messagesDialog,
  unavailable: busy
      ? 'the machine is still answering'
      : person.trim().isEmpty
      ? 'enter your name in the chat'
      : null,
  run: run,
);

/// Replaces the chosen account's password after an explicit request.
Command newMessagePasswordCommand({required bool busy, required VoidCallback run}) => Command(
  id: 'join-reset',
  label: 'New password',
  group: 'Messages',
  home: Home.messagesDialog,
  unavailable: busy ? 'the machine is still answering' : null,
  run: run,
);

/// Opens Element without sending any part of the once-shown login to its website.
Command openElementCommand() => Command(
  id: 'open-element',
  label: 'Open Element',
  group: 'Messages',
  home: Home.messagesDialog,
  run: () => unawaited(desk.open('https://app.element.io/')),
);

/// Ends this computer's connection to a machine that stays listed, or brings it back.
Command connectionCommand({required Machine machine, required VoidCallback run}) => Command(
  id: machine.disconnected ? 'machine.connect' : 'machine.disconnect',
  label: machine.disconnected ? 'Connect' : 'Disconnect',
  group: 'Machine',
  home: Home.machineMenu,
  run: run,
);

/// Stops watching a machine, with the same guard wherever removal is offered.
Command forgetMachineCommand({
  required bool canForget,
  required VoidCallback forget,
  Machine? machine,
  HostRuns? hostRuns,
  String label = 'Forget this machine',
}) => Command(
  id: 'machine.forget',
  label: label,
  group: 'Machine',
  home: Home.machineMenu,
  run: forget,
  unavailable:
      (machine != null && machine.kind == 'host' ? _setupAgainUnavailable(hostRuns, machine.hostProject) : null) ??
      (canForget ? null : 'it is the only machine watched'),
);

/// The machine's daemon actions and any host lifecycle actions, sharing one home.
List<Command> machineCommands({
  required FleetModel fleet,
  Machine? machine,
  HostRuns? hostRuns,
  required bool canForget,
  required bool reachedOverSsh,
  bool canStart = false,
  required VoidCallback checkTheMachine,
  VoidCallback? startThenCheck,
  required VoidCallback showTheProviders,
  required VoidCallback showTheVault,
  VoidCallback? showConnections,
  VoidCallback? showDestinations,
  required VoidCallback showAgents,
  required VoidCallback startTheDaemon,
  required VoidCallback stopTheDaemon,
  required VoidCallback forget,
  List<Command> hostActions = const [],
  VoidCallback? clearTheMachine,
  required Vault vault,
  required void Function(VaultAct act) actOnTheVault,
  required VoidCallback addAUser,
  VoidCallback? unlockWithThePassphrase,
  VoidCallback? makeTheVault,
}) {
  final connected = fleet.reachability == Reachability.connected;
  final notConnected = connected ? null : 'the machine is not answering';
  return <Command>[
    ...hostActions,
    // The one thing a machine that is not answering can still be asked, and only while this
    // interface is the one that logs in: everything else here needs the daemon that is missing.
    Command(
      id: 'machine.start',
      label: 'Start Porelo on this machine',
      group: 'Machine',
      home: Home.machineMenu,
      run: startTheDaemon,
      unavailable: !reachedOverSsh && !canStart
          ? 'its socket is forwarded by somebody else'
          : connected
          ? 'it is already answering'
          : null,
    ),
    // The other half of starting: what a console can do, this can. Tasks run on without their
    // daemon, so what it costs is said before it is done, and it is done only for a machine this
    // interface logs into.
    Command(
      id: 'machine.stop',
      label: 'Stop Porelo on this machine',
      group: 'Machine',
      home: Home.machineMenu,
      run: stopTheDaemon,
      unavailable: !reachedOverSsh ? 'its socket is forwarded by somebody else' : notConnected,
    ),
    Command(
      id: 'machine.doctor',
      label: 'Check whether this machine can run anything',
      group: 'Machine',
      home: Home.machineMenu,
      // Asked of the daemon, so a machine with none running is offered to start it first, where
      // this interface can: precisely then is the check most wanted.
      run: connected || startThenCheck == null || !(reachedOverSsh || canStart) ? checkTheMachine : startThenCheck,
      unavailable: connected || (startThenCheck != null && (reachedOverSsh || canStart))
          ? null
          : 'Porelo is not answering there, and it is not started from here',
    ),
    Command(
      id: 'machine.providers',
      label: 'Show what this machine can authenticate against',
      group: 'Machine',
      home: Home.machineMenu,
      run: showTheProviders,
      unavailable: notConnected,
    ),
    Command(
      id: 'vault.show',
      label: 'Show the vault',
      group: 'Machine',
      home: Home.machineMenu,
      run: showTheVault,
      unavailable: notConnected,
    ),
    // What it connects out with is listed with the vault shut too: the list holds no secret.
    Command(
      id: 'machine.connections',
      label: 'Connections — how this machine connects out',
      group: 'Machine',
      home: Home.machineMenu,
      run: showConnections ?? () {},
      unavailable: notConnected,
    ),
    // Declared as files at the machine, and managed here as well: what a console can, this can.
    Command(
      id: 'machine.destinations',
      label: 'Destinations — the services a credential can be for',
      group: 'Machine',
      home: Home.machineMenu,
      run: showDestinations ?? () {},
      unavailable: showDestinations == null ? 'not offered here' : notConnected,
    ),
    // Needs no daemon: root logs in and Porelo's setup script makes the user, as for a new machine.
    Command(
      id: 'machine.addUser',
      label: 'Add another user that runs work…',
      group: 'Machine',
      home: Home.machineMenu,
      run: addAUser,
    ),
    // The same three the button beside the stop offers one at a time, so each is reachable whichever
    // one the button shows: an open store on a device that is not enrolled still has to be shut.
    for (final (act, id, label) in <(VaultAct, String, String)>[
      (VaultAct.enroll, 'vault.enroll', 'Enroll this device on this machine'),
      (VaultAct.open, 'vault.open', 'Open the vault with this device'),
      (VaultAct.shut, 'vault.shut', 'Shut the vault'),
    ])
      Command(
        id: id,
        label: label,
        group: 'Machine',
        home: Home.machineMenu,
        run: () => actOnTheVault(act),
        unavailable: notConnected ?? vault.whyNot(act),
      ),
    // A fresh machine has no store, and every later step starts from one being there.
    Command(
      id: 'vault.make',
      label: 'Make the vault, in a terminal',
      group: 'Machine',
      home: Home.machineMenu,
      run: makeTheVault ?? () {},
      unavailable:
          notConnected ??
          (!vault.missing
              ? 'this machine has one already'
              : makeTheVault == null
              ? 'its socket is forwarded by somebody else, so nothing here reaches its porelo'
              : null),
    ),
    // The first opening is always by the passphrase: a device can only be enrolled into an open
    // vault. Typed into the machine's own `porelo`, never into this program.
    Command(
      id: 'vault.passphrase',
      label: 'Open the vault with its passphrase, in a terminal',
      group: 'Machine',
      home: Home.machineMenu,
      run: unlockWithThePassphrase ?? () {},
      unavailable:
          notConnected ??
          (vault.readable
              ? 'it is already open'
              : unlockWithThePassphrase == null
              ? 'its socket is forwarded by somebody else, so nothing here reaches its porelo'
              : null),
    ),
    Command(
      id: 'agents.show',
      label: 'Show the agents installed here',
      group: 'Machine',
      home: Home.machineMenu,
      run: showAgents,
      unavailable: notConnected,
    ),
    Command(
      id: 'fleet.refresh',
      label: 'Refresh from the backend',
      group: 'Machine',
      home: Home.machineMenu,
      shortcut: const SingleActivator(LogicalKeyboardKey.f5),
      run: fleet.refresh,
    ),
    Command(
      id: 'fleet.reconnect',
      label: 'Reconnect to the backend',
      group: 'Machine',
      home: Home.machineMenu,
      run: fleet.connect,
    ),
    Command(
      id: 'machine.clear',
      label: 'Clear this machine of everything Porelo put there…',
      group: 'Machine',
      home: Home.machineMenu,
      run: clearTheMachine ?? () {},
      unavailable: clearTheMachine == null ? 'not from here' : null,
    ),
    forgetMachineCommand(canForget: canForget, forget: forget, machine: machine, hostRuns: hostRuns),
  ];
}

/// Every action in the product, in the order the finder should offer them.
///
/// The finder, the title bar and the keyboard all read it, and each entry says where it lives.
///
/// This is the whole list, and it is deliberately shorter than the product will be: about a
/// third of the requirements have no backend method behind them, so their actions do not exist
/// to be named yet. See `doc/Contract-Gaps.md`.
List<Command> commandsFor({
  List<Command> viewActions = const [],
  required FleetModel fleet,
  required Machine machine,
  HostRuns? hostRuns,
  List<Command> hostActions = const [],
  required bool canForget,
  required ShellModel shell,
  required Settings settings,
  required Operations operations,
  required Notifications notifications,
  required Templates templates,
  required VoidCallback openFinder,
  required VoidCallback checkWorkCanStart,
  required void Function(Task task) askToRemove,
  required void Function(Task task) askWhichLog,
  required void Function(Task task) openSession,
  required VoidCallback openDetail,
  required void Function(Task task) continueTheWork,
  required void Function(Task task) recreate,
  required void Function(Task task) nameTheWork,
  required void Function(Task task) widenTheWork,
  required void Function(Task task) enforceOnTheWork,
  required void Function(Task task) narrowTheWork,
  void Function(Task task)? talkForTheWork,
  void Function(Task task)? tellTheWork,
  void Function(Task task)? handInTo,
  void Function(Task task)? takeBackFrom,
  void Function(Task task)? refreshFromItsSource,
  void Function(Task task)? certifyAgain,
  VoidCallback? unlockTheVault,
  required VoidCallback openTheGate,
  required VoidCallback openEgress,
  required VoidCallback removeWhatWasBuilt,
  required String? whyNoRemoval,
  VoidCallback? clearTheProject,
  VoidCallback? startTheAgents,
  required VoidCallback checkTheMachine,
  VoidCallback? startThenCheck,
  required VoidCallback showTheProviders,
  required VoidCallback prepareTheProject,
  VoidCallback? showTheForges,
  required VoidCallback showTheBackups,
  required VoidCallback syncTheUpstream,
  required VoidCallback startWork,
  VoidCallback? showTheMessages,
  VoidCallback? openItsForge,
  String? itsForgeIsMissing,
  VoidCallback? showTheDefault,
  required VoidCallback showAgents,
  required VoidCallback showTheVault,
  VoidCallback? showConnections,
  VoidCallback? showDestinations,
  required void Function(Template job) startFromTemplate,
  required VoidCallback stopEverything,
  required VoidCallback stopEverywhere,
  required VoidCallback watchAnotherMachine,
  FutureOr<void> Function()? prepareServer,
  required VoidCallback startTheDaemon,
  required VoidCallback stopTheDaemon,
  required VoidCallback forget,
  VoidCallback? clearTheMachine,
  required VoidCallback showAbout,
  required VoidCallback refreshAll,
  required bool anyAnswering,
  required Vault vault,
  required void Function(VaultAct act) actOnTheVault,
  VoidCallback? askKeepResolved,
  required VoidCallback askTheWorkUser,
  required VoidCallback addAUser,
  VoidCallback? unlockWithThePassphrase,
  VoidCallback? makeTheVault,
}) {
  final selectedProject = fleet.selectedProject;
  final selectedTask = fleet.selectedTask;
  final latest = operations.latest;

  return <Command>[
    ...viewActions,
    // The title bar: machines, options, about. Everything else lives where it acts.
    Command(
      id: 'machines.add',
      label: 'Watch another machine…',
      group: 'Machines',
      home: Home.appBar,
      run: watchAnotherMachine,
    ),
    prepareServerCommand(open: prepareServer, access: hostRuns?.hostAccess),
    Command(
      id: 'appearance.light',
      label: 'Appearance: light',
      group: 'Options',
      home: Home.appBar,
      checked: settings.appearance == ThemeMode.light,
      run: () => settings.setAppearance(ThemeMode.light),
    ),
    Command(
      id: 'appearance.dark',
      label: 'Appearance: dark',
      group: 'Options',
      home: Home.appBar,
      checked: settings.appearance == ThemeMode.dark,
      run: () => settings.setAppearance(ThemeMode.dark),
    ),
    Command(
      id: 'appearance.system',
      label: 'Appearance: follow the desktop',
      group: 'Options',
      home: Home.appBar,
      checked: settings.appearance == ThemeMode.system,
      run: () => settings.setAppearance(ThemeMode.system),
    ),
    for (final (seconds, words) in const <(int, String)>[
      (0, 'off'),
      (30, 'every 30 seconds'),
      (60, 'every minute'),
      (300, 'every 5 minutes'),
    ])
      Command(
        id: 'refresh.every/$seconds',
        label: 'Refresh automatically: $words',
        group: 'Options',
        home: Home.appBar,
        checked: settings.refreshSeconds == seconds,
        run: () => settings.setRefreshSeconds(seconds),
      ),
    Command(
      id: 'attention.retention',
      label: 'Keep resolved rows for: ${settings.keepResolvedMinutes} minutes…',
      group: 'Options',
      home: Home.appBar,
      run: () => askKeepResolved?.call(),
      unavailable: askKeepResolved == null ? 'options are unavailable here' : null,
    ),
    Command(
      id: 'setup.workUser',
      label: 'New machines run work as: ${settings.workUser}…',
      group: 'Options',
      home: Home.appBar,
      run: askTheWorkUser,
    ),
    Command(
      id: 'refresh.all',
      label: 'Refresh every machine now',
      group: 'Machines',
      shortcut: const SingleActivator(LogicalKeyboardKey.f5, shift: true),
      run: refreshAll,
    ),
    Command(id: 'about.show', label: 'About $productName', group: 'About', home: Home.appBar, run: showAbout),
    Command(
      id: 'everywhere.panic',
      label: 'Stop everything on every machine',
      group: 'Machines',
      shortcut: const SingleActivator(LogicalKeyboardKey.period, control: true, shift: true, alt: true),
      run: stopEverywhere,
      unavailable: anyAnswering ? null : 'no machine is answering',
    ),
    Command(
      id: 'machine.panic',
      label: 'Stop everything on this machine',
      group: 'Machine',
      home: Home.machineTitle,
      // Shift as well as Control: nothing adjacent can be hit by mistake.
      shortcut: const SingleActivator(LogicalKeyboardKey.period, control: true, shift: true),
      run: stopEverything,
      unavailable: fleet.reachability == Reachability.connected ? null : 'the machine is not answering',
    ),
    ...machineCommands(
      fleet: fleet,
      machine: machine,
      hostRuns: hostRuns,
      hostActions: hostActions,
      canForget: canForget,
      reachedOverSsh: machine.needsATunnel,
      canStart: machine.canBeStartedHere,
      checkTheMachine: checkTheMachine,
      startThenCheck: startThenCheck,
      showTheProviders: showTheProviders,
      showTheVault: showTheVault,
      showConnections: showConnections,
      showDestinations: showDestinations,
      showAgents: showAgents,
      startTheDaemon: startTheDaemon,
      stopTheDaemon: stopTheDaemon,
      forget: forget,
      clearTheMachine: clearTheMachine,
      vault: vault,
      actOnTheVault: actOnTheVault,
      addAUser: addAUser,
      unlockWithThePassphrase: unlockWithThePassphrase,
      makeTheVault: makeTheVault,
    ),
    // Needs no machine either: the forges are this computer's, with their tokens in its keychain.
    Command(
      id: 'forges.show',
      label: 'Your forges: where your repositories are, and their tokens',
      group: 'Project',
      home: Home.none,
      run: showTheForges ?? () {},
      unavailable: showTheForges == null ? 'not offered here' : null,
    ),
    ...projectCommands(
      project: selectedProject,
      settings: settings,
      fleet: fleet,
      hostRuns: hostRuns,
      notifications: notifications,
      openTheGate: openTheGate,
      openEgress: openEgress,
      prepareTheProject: prepareTheProject,
      syncTheUpstream: syncTheUpstream,
      showTheBackups: showTheBackups,
      checkWorkCanStart: checkWorkCanStart,
      removeWhatWasBuilt: removeWhatWasBuilt,
      whyNoRemoval: whyNoRemoval,
      clearTheProject: clearTheProject,
      showTheMessages: showTheMessages,
      openItsForge: openItsForge,
      itsForgeIsMissing: itsForgeIsMissing,
      showTheDefault: showTheDefault,
      startTheAgents: startTheAgents,
    ),
    Command(
      id: 'work.start',
      label: 'Start work in this project',
      group: 'Work',
      home: Home.startTile,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
      run: startWork,
      unavailable: StartWork.whyNot(selectedProject?.project) ?? notAnswering(fleet),
    ),
    // One command per named job, so a template turns up in the finder like any other action.
    for (final job in selectedProject == null ? const <Template>[] : templates.forProject(selectedProject.name))
      Command(
        id: 'template.start/${job.project}/${job.name}',
        label: 'Run ${job.name} in ${job.project}',
        group: 'Work',
        home: Home.templateTile,
        run: () => startFromTemplate(job),
        unavailable: !job.startable
            ? 'this job is missing something it needs to run'
            : StartWork.whyNot(selectedProject?.project),
      ),
    Command(
      id: 'detail.open',
      label: 'Open the selected work',
      group: 'Work',
      shortcut: const SingleActivator(LogicalKeyboardKey.enter, control: true),
      run: openDetail,
      unavailable: selectedTask == null ? 'no work selected' : null,
    ),
    Command(
      id: 'detail.close',
      label: 'Close what is open over the frame',
      group: 'Work',
      shortcut: const SingleActivator(LogicalKeyboardKey.escape),
      run: shell.close,
      unavailable: shell.canClose ? null : 'nothing is open over the frame',
    ),
    ...workCommands(
      task: selectedTask,
      fleet: fleet,
      machine: machine,
      askToRemove: askToRemove,
      askWhichLog: askWhichLog,
      openSession: openSession,
      continueTheWork: continueTheWork,
      recreate: recreate,
      nameTheWork: nameTheWork,
      widenTheWork: widenTheWork,
      enforceOnTheWork: enforceOnTheWork,
      narrowTheWork: narrowTheWork,
      talkForTheWork: talkForTheWork,
      tellTheWork: tellTheWork,
      handInTo: handInTo,
      takeBackFrom: takeBackFrom,
      refreshFromItsSource: refreshFromItsSource,
      certifyAgain: certifyAgain,
      unlockTheVault: unlockTheVault,
    ),
    Command(
      id: 'operations.show',
      label: 'Show what this session has run',
      group: 'Machine',
      home: Home.statusLine,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
      run: shell.openOperations,
    ),
    Command(
      id: 'operations.latest',
      label: 'Watch the last operation',
      group: 'Machine',
      run: () => shell.openOperation(latest!.id),
      unavailable: latest == null ? 'nothing has been run from here yet' : null,
    ),
    Command(
      id: 'operations.file',
      label: 'Open the file of everything that was run',
      group: 'Machine',
      run: () => unawaited(operations.openTheFile()),
      unavailable: operations.file == null ? 'nothing here keeps a file of it' : null,
    ),
    Command(
      id: 'finder.open',
      label: 'Find a command',
      group: 'Options',
      shortcut: const SingleActivator(LogicalKeyboardKey.keyK, control: true),
      run: openFinder,
    ),
  ];
}

/// Renders a shortcut the way a keyboard is labeled.
String describeShortcut(SingleActivator shortcut) {
  final parts = <String>[
    if (shortcut.control) 'Ctrl',
    if (shortcut.alt) 'Alt',
    if (shortcut.shift) 'Shift',
    shortcut.trigger.keyLabel,
  ];
  return parts.join('+');
}

/// Opens the dialog for completing a host setup stop.
Command hostPreparationCommand({
  required String project,
  required VoidCallback open,
  bool resolved = false,
  Home home = Home.attentionRow,
}) => Command(
  id: 'host.preparation',
  label: 'Complete setup on the machine',
  group: '$project server',
  home: home,
  run: open,
  unavailable: resolved ? 'this row is resolved' : null,
);

/// Opens a preparing server's complete protocol and stop controls.
Command hostProtocolCommand({required String project, required VoidCallback open, Home home = Home.machineRow}) =>
    Command(id: 'host.protocol', label: 'Open the machine protocol', group: '$project server', home: home, run: open);

/// Copies the public protocol without reopening setup inputs or a terminal.
Command copyHostProtocolCommand({required String project, required VoidCallback copy}) => Command(
  id: 'host.copyProtocol',
  label: 'Copy the protocol',
  group: '$project server',
  home: Home.openedView,
  run: copy,
);

/// Continues an interrupted setup from the row that names its billing server.
Command continueHostPreparationCommand({required String project, required VoidCallback goOn, bool resolved = false}) =>
    Command(
      id: 'host.goOn',
      label: 'Go on',
      group: '$project server',
      home: Home.attentionRow,
      run: goOn,
      unavailable: resolved ? 'this row is resolved' : null,
    );

String? _setupAgainUnavailable(HostRuns? hostRuns, String project) {
  final run = hostRuns?.of(project);
  return run != null && run.ready && (run.running || run.needsYou || run.interrupted)
      ? 'its setup is running again; see its protocol'
      : null;
}

/// Runs the saved setup of a ready server after its previous attempt ended.
Command runHostSetupAgainCommand({required String project, required HostRuns hostRuns}) => Command(
  id: 'host.again',
  label: 'Run its setup again',
  group: '$project server',
  home: Home.machineRow,
  run: () => unawaited(hostRuns.again(project)),
  unavailable: _setupAgainUnavailable(hostRuns, project) ?? hostRuns.againUnavailable(project),
);

/// Continues or gives back a retained server only after its previous command ended.
List<Command> hostRecoveryCommands({
  required HostPreparation run,
  required VoidCallback goOn,
  required VoidCallback takeDown,
  HostAccess? access,
}) {
  final resume = resumeHostPreparationCommand(run: run, resume: goOn, home: Home.machineRow);
  return [
    resume,
    Command(
      id: 'host.takeDown',
      label: run.record.isRental ? 'Return this rental…' : 'Take Porelo off this machine…',
      group: run.name,
      home: Home.machineRow,
      run: takeDown,
      unavailable: resume.unavailable ?? access?.whyNotTakeDown(run.record.hostName),
    ),
  ];
}

/// Continues an interrupted setup or retries a failed attempt after the previous command ended.
Command resumeHostPreparationCommand({
  required HostPreparation run,
  required VoidCallback resume,
  Home home = Home.openedView,
}) => Command(
  id: run.interrupted ? 'host.goOn' : 'host.retry',
  label: run.interrupted ? 'Go on' : 'Try again',
  group: run.name,
  home: home,
  run: resume,
  unavailable:
      run.lockProblem ??
      (run.running
          ? 'the machine setup command is still running'
          : run.ready && !run.needsYou && !run.interrupted || run.givenBack
          ? 'preparation has ended'
          : null),
);

/// Opens the provider's hidden terminal prompt before host setup continues.
Command setScalewayKeyCommand({required VoidCallback run, bool checking = false}) => Command(
  id: 'host.setScalewayKey',
  label: 'Set Scaleway key',
  group: 'Server setup',
  home: Home.openedView,
  run: run,
  unavailable: checking ? 'wait for the Scaleway key check to answer' : null,
);

/// Opens the selected project's existing work under Work.
Command projectWorkCommand({required VoidCallback open}) =>
    Command(id: 'project.itsWork', label: 'Its work, under Work', group: 'Project', home: Home.startTile, run: open);

/// Opens the person's own key and card, from the title bar's options.
Command myKeyCommand({required VoidCallback open}) =>
    Command(id: 'identity.open', label: 'My key and card…', group: 'Options', home: Home.appBar, run: open);

/// Opens an item's details without running the item's main action.
Command listOpenCommand({required String label, required Home home, required VoidCallback open}) =>
    Command(id: 'list.open', label: label, group: 'Details', home: home, run: open);

/// Discloses local details without navigating or changing the item.
Command listDisclosureCommand({required bool expanded, required VoidCallback toggle}) =>
    Command(id: 'list.disclose', label: expanded ? 'Show less' : 'Show more', group: 'Details', run: toggle);

/// Changes a saved forge or removes its local entry through the existing confirmation.
List<Command> forgeRowCommands({
  required String name,
  required VoidCallback change,
  required VoidCallback remove,
  required bool busy,
}) => [
  Command(
    id: 'change',
    label: 'Change its name or token',
    group: name,
    home: Home.forgeRow,
    run: change,
    unavailable: busy ? 'wait for the forge to answer' : null,
  ),
  Command(
    id: 'remove',
    label: 'Remove from this computer',
    group: name,
    home: Home.forgeRow,
    run: remove,
    unavailable: busy ? 'wait for the forge to answer' : null,
  ),
];

Command _attentionRowCommand({
  required String id,
  required String label,
  required VoidCallback run,
  String? unavailable,
}) => Command(id: id, label: label, group: 'Needs you', home: Home.attentionRow, run: run, unavailable: unavailable);

/// Retries only the homeserver forward named by the row.
Command retryAttentionForwardCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'messages.retryForward', label: 'Try again', run: run, unavailable: unavailable);

/// Creates a project's Git repository, from what needs its Project Admin.
Command createRepositoryCommand({required VoidCallback run, String? unavailable}) => _attentionRowCommand(
  id: 'project.createRepository',
  label: "Create the project's Git repository",
  run: run,
  unavailable: unavailable,
);

/// Leads to where a machine waiting for its first token is given it.
Command giveMachineTokenCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'machine.giveToken', label: 'Go to its token', run: run, unavailable: unavailable);

/// Reads a held message before any release or refusal can be decided.
Command readAttentionMessageCommand({required HeldMessage message, required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(
      id: 'message.read',
      label: message.direction == 'in' ? 'Read it, and decide whether ${message.task} gets it' : 'Read it and decide',
      run: run,
      unavailable: unavailable,
    );

/// Starts the existing grant flow for the credential named by the row.
Command grantAttentionCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'authorization.grant', label: 'Grant it', run: run, unavailable: unavailable);

/// Opens the failed operation's retained output.
Command openAttentionOperationCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'operation.open', label: 'Open what it printed', run: run, unavailable: unavailable);

/// Opens review for the work named by the row without approving it.
Command reviewAttentionWorkCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'work.review', label: 'Review at the gate', run: run, unavailable: unavailable);

/// Acknowledges dropped questions only on their own machine.
Command missedQuestionsSeenCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'questions.seen', label: 'Seen', run: run, unavailable: unavailable);

/// Acknowledges a connection notice only on its own machine.
Command machineNoticeSeenCommand({required VoidCallback run, String? unavailable}) =>
    _attentionRowCommand(id: 'machine.noticeSeen', label: 'Seen', run: run, unavailable: unavailable);

/// Closes a list item's detail dialog without changing the item.
Command closeListDetailsCommand(VoidCallback close) =>
    Command(id: 'list.closeDetails', label: 'Close', group: 'Details', home: Home.openedView, run: close);

/// Answers the row's specific blocked connection, keeping a refusal unavailable.
Command questionDecisionCommand({required bool allow, required VoidCallback run, String? unavailable}) => Command(
  id: allow ? 'question.allow' : 'question.block',
  label: allow ? 'Let it through' : 'Keep it blocked',
  group: 'Work',
  home: Home.tileMenu,
  run: run,
  unavailable: unavailable,
);

/// Opens what is known of one piece of work, from its row's menu: the row's own press selects and folds.
Command seeItsDetailsCommand({required VoidCallback run}) =>
    Command(id: 'work.details', label: 'See its details', group: 'Work', home: Home.tileMenu, run: run);

/// Puts away a settled question only on the work that asked it.
Command putAwayQuestionCommand({required VoidCallback run, String? unavailable}) => Command(
  id: 'question.putAway',
  label: 'Got it',
  group: 'Work',
  home: Home.tileMenu,
  run: run,
  unavailable: unavailable,
);

/// Project-menu actions for a person with a role in the project, independent of startup roles.
List<Command> projectTransferCommands({
  required ProjectTransfers transfers,
  required TransferSelection selection,
  required void Function(ProjectTransfer direction) start,
}) => [
  for (final direction in ProjectTransfer.values)
    Command(
      id: direction == ProjectTransfer.push ? 'project.pushApprovedMain' : 'project.takeCentralState',
      label: direction == ProjectTransfer.push ? 'Push the approved main…' : 'Take the central state…',
      group: selection.project,
      home: Home.projectMenu,
      unavailable: transfers.unavailable(selection),
      run: () {
        if (transfers.unavailable(selection) == null) start(direction);
      },
    ),
];

/// The project menu's central transfers for a project on a card host, the person being the card's login.
///
/// [whyNoRight] says why the person holds no working role in the project, null when they do; the host itself refuses
/// what the role does not allow. Without a secrets file ([hasSecrets] false) nothing can feed the central token.
List<Command> cardHostTransferCommands({
  required ProjectTransfers transfers,
  required Machine machine,
  required String project,
  required String? whyNoRight,
  required bool hasSecrets,
  required void Function(ProjectTransfer direction) start,
  bool running = false,
}) {
  final card = machine.hostCard;
  if (card == null || project == defaultProject) return const [];
  final selection = TransferSelection(
    machine: machine,
    person: card.login,
    forge: 'central',
    project: project,
    canPush: whyNoRight == null,
  );
  final why = running
      ? 'A push or pull of this project runs already; wait for its end.'
      : whyNoRight ??
            (hasSecrets ? null : 'Choose your secrets file under My forges first: the central token is read from it.');
  return [
    for (final command in projectTransferCommands(transfers: transfers, selection: selection, start: start))
      why == null
          ? command
          : Command(
              id: command.id,
              label: command.label,
              group: command.group,
              home: command.home,
              unavailable: why,
              run: () {},
            ),
  ];
}

/// Explicit central forge actions for the project menu and selected request.
List<Command> centralReviewCommands({
  required String project,
  required VoidCallback list,
  required VoidCallback create,
  VoidCallback? read,
  VoidCallback? reviews,
  VoidCallback? submit,
  required CentralReviews actions,
}) {
  void run(VoidCallback? action, {bool write = false}) {
    final reason = write ? actions.unavailable : actions.closedReason;
    if (reason != null) throw ForgeRefused(reason);
    if (action == null) throw const ForgeRefused('Choose a central pull request.');
    action();
  }

  return [
    Command(
      id: 'project.centralPullRequests',
      label: 'Read central pull requests…',
      group: project,
      home: Home.projectMenu,
      unavailableNow: () => actions.closedReason,
      run: () => run(list),
    ),
    Command(
      id: 'centralPullRequest.create',
      label: 'Create a central pull request…',
      group: project,
      home: Home.projectMenu,
      unavailableNow: () => actions.unavailable,
      run: () => run(create, write: true),
    ),
    Command(
      id: 'centralPullRequest.read',
      label: 'Read the pull request',
      group: project,
      home: Home.openedView,
      unavailableNow: () => actions.closedReason,
      unavailable: read == null ? 'Choose a central pull request.' : null,
      run: () => run(read),
    ),
    Command(
      id: 'centralPullRequest.reviews',
      label: 'Read its central reviews',
      group: project,
      home: Home.openedView,
      unavailableNow: () => actions.closedReason,
      unavailable: reviews == null ? 'Choose a central pull request.' : null,
      run: () => run(reviews),
    ),
    Command(
      id: 'centralPullRequest.review',
      label: 'Review on the central forge…',
      group: project,
      home: Home.openedView,
      unavailableNow: () => actions.unavailable ?? (submit == null ? 'Choose a central pull request.' : null),
      run: () => run(submit, write: true),
    ),
  ];
}
