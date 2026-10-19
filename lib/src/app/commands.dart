import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_model.dart';
import 'product.dart';
import 'hand_in.dart';
import 'machines.dart';
import 'narrowing.dart';
import 'notifications.dart';
import 'operations.dart';
import 'session.dart';
import 'settings.dart';
import 'shell_model.dart';
import 'start_work.dart';
import 'templates.dart';
import 'vault.dart';
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

  /// The entry that follows a repository, which is how a project comes to a machine.
  followRepository,

  /// The tile that starts work.
  startTile,

  /// A named job's own tile.
  templateTile,

  /// The menu on the selected work's tile.
  tileMenu,

  /// The machine's status line.
  statusLine,
}

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
    this.unavailable,
    this.home = Home.none,
    this.checked,
  });

  /// Stable identifier, used to route a keystroke to this command.
  final String id;

  /// What it is called, in the words the person would search for.
  final String label;

  /// What it belongs to, so a long list stays readable.
  final String group;

  /// What it does.
  final VoidCallback run;

  /// The key that runs it, when it has one.
  final SingleActivator? shortcut;

  /// Why it cannot be run now, or null when it can.
  ///
  /// An unavailable command is still listed. Hiding it would make the finder answer "there is
  /// no such action" when the truth is "not yet, and here is what is missing".
  final String? unavailable;

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
          label: label,
          group: group,
          shortcut: shortcut,
          unavailable: reason,
          home: home,
          checked: checked,
          run: run,
        );

  /// The same command, doing [first] before it runs.
  Command after(VoidCallback first) => Command(
    id: id,
    label: label,
    group: group,
    shortcut: shortcut,
    unavailable: unavailable,
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

/// Why nothing that needs [fleet]'s machine can be done now, or null while it answers.
String? notAnswering(FleetModel fleet) =>
    fleet.reachability == Reachability.connected ? null : 'the machine is not answering';

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
  required Notifications notifications,
  required VoidCallback openTheGate,
  required VoidCallback openEgress,
  required VoidCallback prepareTheProject,
  required VoidCallback syncTheUpstream,
  required VoidCallback showTheBackups,
  required VoidCallback checkWorkCanStart,
  required VoidCallback removeWhatWasBuilt,
  VoidCallback? clearTheProject,
  VoidCallback? showTheMessages,
  VoidCallback? openItsForge,
  String? itsForgeIsMissing,
  VoidCallback? showTheDefault,
  VoidCallback? putOnAServer,
}) {
  const nothing = 'no project selected';
  // default's settings are Porelo's own and fixed: nothing here changes what it may reach.
  final isDefault = project?.name == defaultProject;
  final noFile = project == null
      ? nothing
      : project.canBeActedOn
      ? null
      : '${project.name} is not a project this machine follows';
  return <Command>[
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
      unavailable: project == null ? nothing : null,
    ),
    // Only where there is a conversation: a project that names a peer on a transport of its own.
    Command(
      id: 'project.messages',
      label: 'Messages — the conversation of this project, and who has joined it',
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
    // The repositories worked on without a project: added by address or picked at a forge, and
    // taken out again once a followed project names them.
    Command(
      id: 'project.default',
      label: 'Repositories worked on without a project',
      group: 'Project',
      home: Home.projectMenu,
      run: showTheDefault ?? () {},
      unavailable: project == null
          ? nothing
          : showTheDefault == null
          ? 'not offered here'
          : project.name != defaultProject
          ? 'only default holds repositories without a project'
          : null,
    ),
    Command(
      id: 'project.backups',
      label: 'Show what has been backed up here',
      group: 'Project',
      home: Home.projectMenu,
      run: showTheBackups,
      unavailable: project == null ? nothing : null,
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
      label: 'Clear this project from the machine, and its keys at the forge…',
      group: 'Project',
      home: Home.projectMenu,
      run: clearTheProject ?? () {},
      unavailable: project == null
          ? nothing
          : clearTheProject == null
          ? 'not from here'
          : project.name == defaultProject
          ? 'default is always there: it is where work without a project goes'
          : null,
    ),
    // `porelo-host` does it; this only opens the page that runs it and shows what it says.
    Command(
      id: 'project.server',
      label: 'Put this project on a server…',
      group: 'Project',
      home: Home.projectMenu,
      run: putOnAServer ?? () {},
      unavailable: project == null
          ? nothing
          : project.name == defaultProject
          ? 'default is this machine\'s own: it goes on no server'
          : putOnAServer == null
          ? 'porelo-host is not installed beside the interface'
          : null,
    ),
    Command(
      id: 'project.delete',
      label: 'Stop following this project',
      group: 'Project',
      home: Home.projectMenu,
      run: removeWhatWasBuilt,
      // **Takes the name, not the file**, so a project whose file is gone can still be cleared.
      unavailable: project == null
          ? nothing
          : project.name == defaultProject
          ? 'default is always there: it is where work without a project goes'
          : null,
    ),
  ].map((command) => command.unless(notAnswering(fleet))).toList();
}

/// What one machine can be told to do, from the menu in its title.
List<Command> machineCommands({
  required FleetModel fleet,
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
      label: 'Clear this machine of everything Porelo put there, and its keys at the forge…',
      group: 'Machine',
      home: Home.machineMenu,
      run: clearTheMachine ?? () {},
      unavailable: clearTheMachine == null ? 'not from here' : null,
    ),
    Command(
      id: 'machine.forget',
      label: 'Forget this machine',
      group: 'Machine',
      home: Home.machineMenu,
      run: forget,
      // Never the last one: a frame with no machine behind it has nothing to say.
      unavailable: canForget ? null : 'it is the only machine watched',
    ),
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
  required FleetModel fleet,
  required Machine machine,
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
  VoidCallback? unlockTheVault,
  required VoidCallback openTheGate,
  required VoidCallback openEgress,
  required VoidCallback removeWhatWasBuilt,
  VoidCallback? clearTheProject,
  VoidCallback? putOnAServer,
  required VoidCallback checkTheMachine,
  VoidCallback? startThenCheck,
  required VoidCallback showTheProviders,
  required VoidCallback prepareTheProject,
  required VoidCallback followARepository,
  VoidCallback? fromARepository,
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
  required VoidCallback startTheDaemon,
  required VoidCallback stopTheDaemon,
  required VoidCallback forget,
  VoidCallback? clearTheMachine,
  required VoidCallback showAbout,
  required VoidCallback refreshAll,
  required bool anyAnswering,
  required Vault vault,
  required void Function(VaultAct act) actOnTheVault,
  required VoidCallback askTheWorkUser,
  required VoidCallback addAUser,
  VoidCallback? unlockWithThePassphrase,
  VoidCallback? makeTheVault,
}) {
  final selectedProject = fleet.selectedProject;
  final selectedTask = fleet.selectedTask;
  final latest = operations.latest;

  return <Command>[
    // The title bar: machines, options, about. Everything else lives where it acts.
    Command(
      id: 'machines.add',
      label: 'Watch another machine…',
      group: 'Machines',
      home: Home.appBar,
      run: watchAnotherMachine,
    ),
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
      id: 'setup.workUser',
      label: 'New machines run work as: ${settings.workUser}…',
      group: 'Options',
      home: Home.appBar,
      run: askTheWorkUser,
    ),
    Command(id: 'refresh.all', label: 'Refresh every machine now', group: 'Machines', run: refreshAll),
    Command(id: 'about.show', label: 'About $productName', group: 'About', home: Home.appBar, run: showAbout),
    Command(
      id: 'everywhere.panic',
      label: 'Stop everything on every machine',
      group: 'Machines',
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
    // Needs no machine: the forge is reached from this computer, with the person's own login.
    Command(
      id: 'project.fromRepository',
      label: 'A project from a repository you have',
      group: 'Project',
      home: Home.none,
      run: fromARepository ?? () {},
      unavailable: fromARepository == null ? 'not offered here' : null,
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
    Command(
      id: 'project.follow',
      label: 'Follow a project',
      group: 'Project',
      home: Home.followRepository,
      run: followARepository,
      unavailable: notAnswering(fleet),
    ),
    ...projectCommands(
      project: selectedProject,
      fleet: fleet,
      notifications: notifications,
      openTheGate: openTheGate,
      openEgress: openEgress,
      prepareTheProject: prepareTheProject,
      syncTheUpstream: syncTheUpstream,
      showTheBackups: showTheBackups,
      checkWorkCanStart: checkWorkCanStart,
      removeWhatWasBuilt: removeWhatWasBuilt,
      clearTheProject: clearTheProject,
      putOnAServer: putOnAServer,
      showTheMessages: showTheMessages,
      openItsForge: openItsForge,
      itsForgeIsMissing: itsForgeIsMissing,
      showTheDefault: showTheDefault,
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
      unavailable: shell.anythingOpen ? null : 'nothing is open over the frame',
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
