import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/central_release.dart';
import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/host_progress.dart';
import 'command_menu.dart';
import 'organization_token_words.dart';
import 'tokens.dart';
import 'window_size.dart';
import 'filtered_list_section.dart';

/// The stop for every machine at once, at the foot of the tree where it is always on screen: work is
/// stopped, never removed.
class StopEverywhere extends StatelessWidget {
  /// Constructor taking what pressing it does, or null where nothing answers.
  const StopEverywhere({required this.onPressed, super.key});

  /// What pressing it does, or null where nothing answers.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    return Tooltip(
      message: 'Stop everything on every machine (Ctrl+Shift+Alt+.)\nWork is stopped, never removed.',
      child: TextButton.icon(
        key: const Key('stop-everywhere'),
        style: TextButton.styleFrom(
          minimumSize: Size(Sizes.touchTarget, WindowSize.fromContext(context).treeRowHeight),
        ),
        onPressed: onPressed,
        icon: Icon(Icons.pan_tool_outlined, size: Sizes.rowIcon, color: red),
        label: Text('Stop everything', style: TextStyle(color: red)),
      ),
    );
  }
}

/// What a machine holds of one repository of a project: its row's words, whether it carries it (null where nobody
/// said), and why work cannot start in it there now, where it cannot.
typedef OnTheMachine = ({String words, bool? carried, String? startRefused});

/// What a machine an organization's card names holds of [repository] of [project], for its row on the project's page
/// opened from that machine: carried, not carried or held; its state at central; the work running in it. [progress] is
/// what the machine said of the project, null where it said nothing of it; [progressRead] is false where the machine
/// was not asked, and [tasks] null where its work was not read: each then says not read, never none. What the
/// machine's own daemon says of it in [listed] is taken before any of these, where it says it, except that a project
/// the machine waits for a token for is never called carried, and says it waits for the token of [forge].
String repositoryOnTheMachine({
  required String project,
  required String repository,
  required HostProjectProgress? progress,
  required bool progressRead,
  required List<Task>? tasks,
  List<String>? carriedAlone,
  Repository? listed,
  String forge = 'central forge',
}) {
  final row = progress?.repositories.where((each) => each.repository == repository).firstOrNull;
  final held = _standing(
    repository: repository,
    progress: progress,
    progressRead: progressRead,
    carriedAlone: carriedAlone,
    listed: listed,
    forge: forge,
  ).words;
  final host = progressRead && row?.state == 'taken' ? (row?.central ?? const HostRepositoryCentral()) : null;
  final daemon = listed?.central;
  // The two may disagree, one older than the other: up to date never hides what is not.
  final central = daemon != null && (daemon != 'up-to-date' || host == null || host.state == 'up-to-date')
      ? centralWords(listed!)
      // One the machine does not carry has no copy of its own to stand against central, whatever the host said.
      : listed?.carriedHere == false
      ? null
      : host != null
      ? host.words
      : !progressRead
      ? 'central: not read'
      : listed?.carriedHere == true
      ? 'central: not reported'
      : null;
  return [held, ?central, workIn(project: project, repository: repository, listed: listed, tasks: tasks)].join(' · ');
}

/// Whether the machine carries [repository], as [repositoryOnTheMachine] words it: true where it carries or holds it,
/// false where it does not, null where nobody said or it is on its way there.
bool? carriedOnTheMachine({
  required String repository,
  required HostProjectProgress? progress,
  required bool progressRead,
  List<String>? carriedAlone,
  Repository? listed,
  String forge = 'central forge',
}) => _standing(
  repository: repository,
  progress: progress,
  progressRead: progressRead,
  carriedAlone: carriedAlone,
  listed: listed,
  forge: forge,
).carried;

/// Why work cannot start in [repository] on the machine, as [repositoryOnTheMachine] words it: one it does not carry,
/// has not taken yet, or one of a project it waits for a token for; null where nothing said here refuses it.
String? startRefusedOnTheMachine({
  required String repository,
  required HostProjectProgress? progress,
  required bool progressRead,
  List<String>? carriedAlone,
  Repository? listed,
  String forge = 'central forge',
}) => _standing(
  repository: repository,
  progress: progress,
  progressRead: progressRead,
  carriedAlone: carriedAlone,
  listed: listed,
  forge: forge,
).startRefused;

/// The states of a repository on its host that a wait of its project for the token does not touch.
const _waitsNot = {'taken', 'no-central', 'not-carried'};

/// Carried, not carried, held or waiting, in words and as a fact, with why work cannot start there, for
/// [repositoryOnTheMachine], [carriedOnTheMachine] and [startRefusedOnTheMachine].
OnTheMachine _standing({
  required String repository,
  required HostProjectProgress? progress,
  required bool progressRead,
  List<String>? carriedAlone,
  Repository? listed,
  String forge = 'central forge',
}) {
  final row = progress?.repositories.where((each) => each.repository == repository).firstOrNull;
  final alone = carriedAlone != null && carriedAlone.contains(repository);
  final notHere = carriedAlone != null && !alone;
  final daemonCarried = listed == null ? null : carriedWords(listed);
  final notCarried = 'This machine does not carry $repository, so work cannot start in it here.';
  final waits = waitingWords(progress, forge);
  if (listed?.carriedHere == false) {
    // Not carried here, so nothing of it is held here, whatever the project is.
    return (words: daemonCarried!, carried: false, startRefused: notCarried);
  }
  // Waiting for a token, the machine takes nothing more of the project, whatever its daemon lists: never called
  // carried. One it has taken already stays carried while it waits for another (seen live); one with no central
  // address, one the host does not carry, and one the organization puts on another machine do not wait here.
  if (progressRead && waits != null && !_waitsNot.contains(row?.state)) {
    if (notHere) return (words: 'not carried here', carried: false, startRefused: notCarried);
    return (
      words: waits,
      carried: null,
      startRefused: 'The machine $waits, and takes no repository before then, so work cannot start in $repository.',
    );
  }
  // Held is the project's state: it holds only what the machine carries of it, never one the host left out or that is
  // still on its way. A host that lists no repositories says nothing of which, so only the left-out ones are excluded.
  final heldHere =
      listed?.carriedHere == true || (progress?.repositories.isEmpty ?? true ? !notHere : row?.state == 'taken');
  if (progressRead && progress?.state == 'held' && heldHere) {
    return (words: 'held: ${progress?.why ?? 'it has unpushed work'}', carried: true, startRefused: null);
  }
  if (daemonCarried != null) {
    return (
      words: alone ? 'carried here alone' : daemonCarried,
      carried: listed?.carriedHere,
      startRefused: listed?.carriedHere == false ? notCarried : null,
    );
  }
  if (!progressRead) {
    // What the organization planned for the machine is no word that it carries it.
    return notHere
        ? (words: 'not carried here', carried: false, startRefused: notCarried)
        : (words: 'carried: not read', carried: null, startRefused: null);
  }
  final notYet = 'The machine has not taken $repository yet, so work cannot start in it here.';
  return switch (row?.state) {
    'taken' => (words: alone ? 'carried here alone' : 'carried', carried: true, startRefused: null),
    'waiting' => (words: 'not carried yet', carried: null, startRefused: notYet),
    'no-central' => (words: 'not carried: it names no central address', carried: false, startRefused: notCarried),
    'not-carried' => (words: 'not carried here', carried: false, startRefused: notCarried),
    null => (words: notHere ? 'not carried here' : 'not carried', carried: false, startRefused: notCarried),
    // A word of a later host, shown as it comes.
    final state => (words: 'not carried: $state', carried: false, startRefused: notCarried),
  };
}

/// The work of [repository] of [project] for its row: as the machine whose daemon listed it as [listed] counts it,
/// else from the machine's list of work, [tasks], where that daemon lists it with no count at all and does not say it
/// does not carry it, as an older Porelo does; otherwise not reported, never none.
String workIn({
  required String project,
  required String repository,
  required Repository? listed,
  required List<Task>? tasks,
}) {
  if (listed == null) return 'tasks: not reported';
  if (countedIn(project: project, repository: listed, tasks: tasks) case final counted?) return counted;
  final uncounted = listed.tasks == null && listed.running == null;
  return uncounted && listed.carriedHere != false
      ? runningIn(project: project, repository: repository, tasks: tasks)
      : 'tasks: not reported';
}

/// What the machine whose daemon listed [listed] of [project] holds of it, for its row on the project's page opened
/// from that machine, where no organization's card names the machine: carried or not, its state at central, its work.
/// What that daemon does not say is said as before: [carried] is whether the machine carries the project for this
/// person, who has not taken it yet.
String repositoryOnAMachine({
  required String project,
  required Repository listed,
  required bool carried,
  required List<Task>? tasks,
}) {
  final central = centralWords(listed) ?? (listed.carriedHere == true ? 'central: not reported' : null);
  return [
    switch (listed.carriedHere) {
      true when carried => 'carried, not taken yet',
      null => carried ? 'carried, not taken yet' : 'on the machine',
      _ => carriedWords(listed)!,
    },
    ?central,
    workIn(project: project, repository: listed.name, listed: listed, tasks: tasks),
  ].join(' · ');
}

/// Whether [repository] is carried on the machine whose daemon listed it, as that daemon says; null where it says
/// nothing of it, as on a machine that is no host of the project, which leaves the window's earlier way.
String? carriedWords(Repository repository) => switch (repository.carriedHere) {
  true => 'carried',
  false => 'not carried here',
  null => null,
};

/// How [repository] stands against central, as the machine whose daemon listed it says; null where it says nothing,
/// which is never up to date. A word of a later Porelo is shown as it comes, and a count ahead only with when it was
/// answered.
String? centralWords(Repository repository) {
  final ahead = repository.ahead;
  final when = DateTime.tryParse(repository.aheadMeasured ?? '');
  String commits(int n) => n == 1 ? '1 commit' : '$n commits';
  return switch (repository.central) {
    null => null,
    // Ahead by none says nothing of how far, as the host's own answer does not.
    'ahead' when ahead != null && ahead > 0 && when != null => '${commits(ahead)} ahead of central${_asOf(when)}',
    'ahead' => 'ahead of central, by how much not reported',
    'up-to-date' => 'at central',
    'moved-on' => 'central moved on',
    'cannot-say' => 'cannot say: ${centralWhyWords(repository.centralWhy) ?? 'no reason reported'}',
    'no-central' => 'no central forge',
    final state => 'central: $state',
  };
}

String _asOf(DateTime when) {
  final ago = DateTime.now().difference(when);
  if (ago.isNegative || ago.inMinutes < 1) return ', answered just now';
  if (ago.inMinutes < 60) return ', as of ${ago.inMinutes} minutes ago';
  if (ago.inHours < 48) return ', as of ${ago.inHours} hours ago';
  return ', as of ${ago.inDays} days ago';
}

/// The work of [repository] of [project], as the machine whose daemon listed it counts it, with the names of the
/// running work from [tasks] where they agree; null where the daemon does not count, which leaves [runningIn]. Not
/// read where [tasks] is null, as the machine does not answer now and its count is its last.
String? countedIn({required String project, required Repository repository, required List<Task>? tasks}) {
  final (counted, listedUp) = (repository.tasks, repository.running);
  if (counted == null || listedUp == null) return null;
  if (tasks == null) return 'tasks: not read';
  bool here(Task task) => task.project == project && task.repository == repository.name;
  // A task whose agent said its work is done is up, and counted so by the machine, but runs no work.
  final done = tasks.where((task) => here(task) && task.running && !task.runningWork).length;
  final up = listedUp - done < 0 ? 0 : listedUp - done;
  final names = [
    for (final task in tasks)
      if (task.runningWork && here(task)) task.shown == task.name ? task.task : task.shown,
  ];
  final of = '$up of ${counted == 1 ? '1 task' : '$counted tasks'} running';
  return names.isNotEmpty && names.length == up ? '$of: ${names.join(', ')}' : of;
}

/// The work running in [repository] of [project], by the names given at its start; not read where [tasks] is null.
String runningIn({required String project, required String repository, required List<Task>? tasks}) {
  if (tasks == null) return 'tasks: not read';
  final running = [
    for (final task in tasks)
      // From a machine that names no short one, its name within the project, as before.
      if (task.runningWork && task.project == project && task.repository == repository)
        task.shown == task.name ? task.task : task.shown,
  ];
  return switch (running.length) {
    0 => 'no task running',
    1 => '1 task running: ${running.single}',
    final count => '$count tasks running: ${running.join(', ')}',
  };
}

/// The selected project above its work: what it is, what state it is in, and its menu.
class ProjectHeader extends StatelessWidget {
  /// Constructor taking the project and what it can be told to do.
  const ProjectHeader({
    required this.project,
    required this.muted,
    required this.menu,
    this.highlight,
    this.onShown,
    this.onSync,
    this.onBackups,
    this.onOpens,
    this.onReach,
    this.onStart,
    this.startUnavailable,
    this.homeserver,
    this.showTitle = true,
    this.onTheMachine,
    this.waits,
    this.waitsWhy,
    this.giveToken,
    this.bringToCentral,
    this.centralSaid,
    this.storeCentralToken,
    super.key,
  });

  /// *Bring it to central…*, shown as a button of its own while it can run; null where it is not offered here.
  final Command? bringToCentral;

  /// What the last bringing of the project to central said, until the next one; null where none ran.
  final CentralReleaseSaid? centralSaid;

  /// *Store the central token…*, beside [centralSaid] where the machine said it holds none; null otherwise.
  final Command? storeCentralToken;

  /// What the machine waits for before it takes any of the project, as its token, said in place of carried; null
  /// where it waits for nothing of this person's or was not asked.
  final String? waits;

  /// Why the machine asks for the token, beside [waits].
  final String? waitsWhy;

  /// *Give it my … token…*, beside [waits] and on each repository's row; null where it waits for none.
  final Command? giveToken;

  /// What the machine holds of each repository, in words beside its row, where the page was opened from that machine;
  /// a repository only the machine names gets a row of its own, and those it does not carry fold below the rest.
  final Map<String, OnTheMachine>? onTheMachine;

  /// Where a Matrix client here reaches the project's homeserver, or why it cannot; null where nobody
  /// joined its conversation from here.
  final String? homeserver;

  /// Whether this projection supplies the page heading and its menu.
  final bool showTitle;

  /// Starts work in one of its repositories, from its row's button or menu.
  final void Function(String repository)? onStart;

  /// Why work cannot start there now, or null.
  final String? startUnavailable;

  /// The project.
  final ProjectOnScreen project;

  /// Asks one repository's upstream how far behind it is, now.
  final void Function(String repository)? onSync;

  /// Shows what has been backed up of one repository.
  final void Function(String repository)? onBackups;

  /// Shows what work in one repository would open, creating nothing.
  final void Function(String repository)? onOpens;

  /// Shows, and changes, what one repository adds to what the project may reach.
  final void Function(String repository)? onReach;

  /// Whether nothing about it is notified.
  final bool muted;

  /// What it can be told to do.
  final List<Command> menu;

  /// The command the finder went to.
  final String? highlight;

  /// Called once the menu opened on [highlight].
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = project.project;
    // default is no project anybody prepares: Porelo's own settings, fixed. What another
    // project lacks is not missing there, and saying so sent a new person looking for it.
    final isDefault = project.name == defaultProject;
    final listed = workRepositoriesOf(project.name, p.repositoryStates);
    final workRepositories = <Repository>[
      ...listed,
      for (final name in onTheMachine?.keys ?? const <String>[])
        if (!listed.any((each) => each.name == name) && isAWorkRepository(project.name, name)) Repository(name: name),
    ];
    // What the machine carries first; what it does not carry folds below, counted, so the few placed there show.
    bool? carried(Repository repository) => onTheMachine?[repository.name]?.carried;
    final carriedFirst = [
      ...workRepositories.where((each) => carried(each) == true),
      ...workRepositories.where((each) => carried(each) == null),
    ];
    // Nothing to put first: the list stays whole and open.
    final here = carriedFirst.isEmpty ? workRepositories : carriedFirst;
    final notHere = carriedFirst.isEmpty
        ? const <Repository>[]
        : workRepositories.where((each) => carried(each) == false).toList();
    final facts = <String>[
      if (!p.prepared && !isDefault && !p.carried) 'environment not prepared',
      if (p.environmentIsStale) 'environment older than its project file',
      if (p.pending > 0) '${p.pending} waiting at the gate',
      if (muted) 'not notified',
      if (!project.canBeActedOn && !isDefault && !p.carried && waits == null) 'not on this machine',
      // Never carried while the machine says it waits: it takes nothing of the project before then.
      if (p.carried && waits == null) 'carried by this machine; starting work takes it here',
      ?waits,
    ];
    final token = giveToken;
    final counts =
        '${project.running} of ${project.howMuchWork} running'
        '${p.securityClass.isEmpty ? '' : ' · ${p.securityClass}'}';
    // Laid out as Machines and Projects are (walk 10): the project as the page's
    // heading with its menu beside it, a line about it, then its repositories, a card each.
    return Column(
      key: const Key('project-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showTitle)
          Wrap(
            spacing: Space.normal,
            runSpacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(project.label, key: const Key('project-title'), style: theme.textTheme.headlineSmall),
              CommandMenu(
                key: const Key('project-menu'),
                commands: menu,
                tooltip: 'What ${project.label} can be told to do',
                highlight: highlight,
                onShown: onShown,
              ),
            ],
          ),
        const SizedBox(height: Space.tight),
        Text(counts, key: const Key('project-counts'), style: theme.textTheme.bodySmall),
        if (facts.isNotEmpty)
          Text(facts.join('  ·  '), key: const Key('project-facts'), style: theme.textTheme.bodySmall),
        if (waits != null) ...[
          if (waitsWhy case final why?)
            Text(why, key: const Key('project-waits-why'), style: theme.textTheme.bodySmall),
          if (token != null && token.visible)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Tooltip(
                message: token.unavailable ?? token.label,
                child: FilledButton.tonal(
                  key: const Key('project-give-token'),
                  onPressed: token.available ? token.run : null,
                  child: Text(token.label),
                ),
              ),
            ),
        ],
        if (bringToCentral case final bring? when bring.visible && bring.available)
          Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: FilledButton.tonal(
              key: const Key('project-bring-to-central'),
              onPressed: bring.run,
              child: Text(bring.label),
            ),
          ),
        if (centralSaid case final said?)
          Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: Text(
              said.words,
              key: const Key('project-central-said'),
              style: said.refused
                  ? theme.textTheme.bodySmall?.copyWith(color: scheme.error)
                  : theme.textTheme.bodySmall,
            ),
          ),
        if (storeCentralToken case final store? when store.visible)
          Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: Tooltip(
              message: store.unavailable ?? store.label,
              child: FilledButton.tonal(
                key: const Key('project-store-central-token'),
                onPressed: store.available ? store.run : null,
                child: Text(store.label),
              ),
            ),
          ),
        // How far behind, for a project whose only repository is its own, and for default.
        if (p.behindReason.isNotEmpty && (isDefault || workRepositories.isEmpty))
          Text(
            p.behindWords,
            key: const Key('project-behind'),
            style: p.hasFallenBehind
                ? theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)
                : theme.textTheme.bodySmall,
          ),
        if (isDefault)
          Text(
            'Your repositories, worked on with Porelo’s own settings.',
            key: const Key('default-what'),
            style: theme.textTheme.bodySmall,
          ),
        if (homeserver case final words?)
          Text(words, key: const Key('project-homeserver'), style: theme.textTheme.bodySmall),
        if (workRepositories.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.normal),
          for (final (part, title, open) in [
            (here, 'Repositories', true),
            (notHere, 'Not carried here (${notHere.length})', false),
          ])
            if (part.isNotEmpty)
              _Repositories(
                key: Key(open ? 'project-repositories' : 'project-repositories-not-carried'),
                title: title,
                initiallyOpen: open,
                repositories: part,
                onTheMachine: onTheMachine ?? const {},
                giveToken: waits == null ? null : giveToken,
                onStart: project.canBeActedOn ? onStart : null,
                startUnavailable: startUnavailable,
                onSync: project.canBeActedOn ? onSync : null,
                onBackups: project.canBeActedOn ? onBackups : null,
                onOpens: project.canBeActedOn ? onOpens : null,
                onReach: project.canBeActedOn ? onReach : null,
              ),
        ],
      ],
    );
  }
}

/// The repositories work is done in on [project]'s page, one row each (walk 10), as the daemon names them.
///
/// Another project's own repository holds its file and planning and is never worked in, so it is not one of them, unless
/// it is the only one. default has no own repository: every one it holds is listed, except a row named default, which
/// an older Porelo answered for the project itself.
List<Repository> workRepositoriesOf(String project, List<Repository> states) => <Repository>[
  for (final each in states)
    if (isAWorkRepository(project, each.name) && (project == defaultProject || !each.own || states.length == 1)) each,
];

/// Whether [repository] may be a row on [project]'s page, whoever names it, the daemon or a host: never a row named
/// default on default's page, which an older Porelo answered for the project itself.
bool isAWorkRepository(String project, String repository) => project != defaultProject || repository != defaultProject;

/// A project's repositories, a card each, as machines and projects are listed.
class _Repositories extends StatelessWidget {
  const _Repositories({
    required this.title,
    required this.initiallyOpen,
    required this.repositories,
    required this.onTheMachine,
    this.giveToken,
    this.onStart,
    this.startUnavailable,
    this.onSync,
    this.onBackups,
    this.onOpens,
    this.onReach,
    super.key,
  });

  final String title;
  final bool initiallyOpen;
  final List<Repository> repositories;
  final Map<String, OnTheMachine> onTheMachine;
  final Command? giveToken;
  final void Function(String repository)? onStart;
  final String? startUnavailable;
  final void Function(String repository)? onSync;
  final void Function(String repository)? onBackups;
  final void Function(String repository)? onOpens;
  final void Function(String repository)? onReach;

  @override
  Widget build(BuildContext context) => FilteredListSection(
    title: title,
    storageId: initiallyOpen ? 'project-repositories' : 'project-repositories-not-carried',
    collapsible: true,
    initiallyOpen: initiallyOpen,
    rows: [
      for (final repository in repositories)
        (
          words: repository.name,
          child: _RepositoryLine(
            repository: repository,
            onTheMachine: onTheMachine[repository.name],
            giveToken: giveToken,
            onStart: onStart,
            startUnavailable: startUnavailable,
            onSync: onSync,
            onBackups: onBackups,
            onOpens: onOpens,
            onReach: onReach,
          ),
        ),
    ],
  );
}

/// One of a project's repositories, as a project is one in the list of projects: its name, how far
/// it has got, a start button, and a menu of what can be done with it. Its limits are in
/// that menu too, not on the row: not what a day's work needs (walk 10).
class _RepositoryLine extends StatelessWidget {
  const _RepositoryLine({
    required this.repository,
    this.onTheMachine,
    this.giveToken,
    this.onStart,
    this.startUnavailable,
    this.onSync,
    this.onBackups,
    this.onOpens,
    this.onReach,
  });

  final Repository repository;
  final OnTheMachine? onTheMachine;
  final Command? giveToken;
  final void Function(String repository)? onStart;
  final String? startUnavailable;
  final void Function(String repository)? onSync;
  final void Function(String repository)? onBackups;
  final void Function(String repository)? onOpens;
  final void Function(String repository)? onReach;

  @override
  Widget build(BuildContext context) {
    final name = repository.name;
    final start = repositoryStartCommand(
      repository: name,
      onStart: onStart,
      unavailable: startUnavailable,
      carriedHere: repository.carriedHere,
      // Refused where the machine does not carry it, has not taken it yet, or waits for its token: said as such, never
      // read from the row's words.
      refused: onTheMachine?.startRefused,
    );
    final state = <String>[
      ?onTheMachine?.words,
      if (repository.pending > 0) '${repository.pending} waiting at the gate',
      if (repository.behindReason.isNotEmpty) repository.behindWords,
    ].join(' · ');
    return ListTile(
      key: Key('repository-$name'),
      leading: const Icon(Icons.source_outlined),
      title: Text(name),
      subtitle: Text(state),
      onTap: start.available ? start.run : null,
      trailing: CommandMenu(
        key: Key('repository-menu $name'),
        tooltip: 'What can be done with $name',
        commands: [
          start,
          // Offered where this repository waits for it, never on one carried or not carried here.
          if (onTheMachine?.carried == null) ?giveToken,
          Command(
            id: 'sync-$name',
            label: "Ask $name's upstream how far behind it is, now",
            group: 'Repositories',
            home: Home.repositoryRow,
            run: () => onSync?.call(name),
            unavailable: onSync == null ? 'This repository is not on this machine.' : null,
          ),
          Command(
            id: 'backups-$name',
            label: 'Backups of $name',
            group: 'Repositories',
            home: Home.repositoryRow,
            run: () => onBackups?.call(name),
            unavailable: onBackups == null ? 'This repository is not on this machine.' : null,
          ),
          Command(
            id: 'opens-$name',
            label: 'Show what work in $name would open, creating nothing',
            group: 'Repositories',
            home: Home.repositoryRow,
            run: () => onOpens?.call(name),
            unavailable: onOpens == null ? 'This repository is not on this machine.' : null,
          ),
          Command(
            id: 'reach-$name',
            label: 'What $name may reach, on top of what the project grants',
            group: 'Repositories',
            home: Home.repositoryRow,
            run: () => onReach?.call(name),
            unavailable: onReach == null ? 'This repository is not on this machine.' : null,
          ),
          if (repository.limits case final limits?)
            Command(
              id: 'limits-$name',
              label: 'Its limits: ${limits.words}',
              group: 'Repositories',
              home: Home.repositoryRow,
              run: () {},
              unavailable: 'Limits are set in the project repository.',
            ),
        ],
      ),
    );
  }
}
