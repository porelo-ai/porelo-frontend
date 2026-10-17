import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import 'command_menu.dart';
import 'tokens.dart';

/// The stop for every machine at once, at the foot of the tree where it is always on screen.
/// The stop for every machine at once: work is stopped, never removed.
class StopEverywhere extends StatelessWidget {
  /// Constructor taking what pressing it does, or null where nothing answers.
  const StopEverywhere({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    return Tooltip(
      message: 'Stop everything on every machine\nWork is stopped, never removed.',
      child: TextButton.icon(
        key: const Key('stop-everywhere'),
        onPressed: onPressed,
        icon: Icon(Icons.pan_tool_outlined, size: Sizes.rowIcon, color: red),
        label: Text('Stop everything', style: TextStyle(color: red)),
      ),
    );
  }
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
    this.onCheck,
    this.checking = false,
    this.checked = const <String>[],
    this.onBackups,
    this.onOpens,
    this.onReach,
    this.onStart,
    this.startUnavailable,
    this.homeserver,
    super.key,
  });

  /// Where a Matrix client here reaches the project's homeserver, or why it cannot; null where nobody
  /// joined its conversation from here.
  final String? homeserver;

  /// Starts work in one of its repositories: a repository's own menu, since work is always in one
  /// (walk 10).
  final void Function(String repository)? onStart;

  /// Why work cannot start there now, or null.
  final String? startUnavailable;

  /// The project.
  final ProjectOnScreen project;

  /// Asks one repository's upstream how far behind it is, now.
  final void Function(String repository)? onSync;

  /// Fetches the project now and asks its repositories' upstream; null for a project not followed.
  final VoidCallback? onCheck;

  /// Whether that check runs now.
  final bool checking;

  /// What the last check found, a line each.
  final List<String> checked;

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
    // default is no project anybody follows or prepares: Porelo's own settings, fixed. What a
    // followed project lacks is not missing there, and saying so sent a new person looking for it.
    final isDefault = project.name == defaultProject;
    // The repositories work is done in, one row each (walk 10): the project's own, which
    // holds its file and planning and is never worked in, is not one of them.
    final workRepositories = isDefault
        ? const <Repository>[]
        : <Repository>[
            for (final each in p.repositoryStates)
              if (!each.own || p.repositoryStates.length == 1) each,
          ];
    final facts = <String>[
      if (!p.prepared && !isDefault) 'environment not prepared',
      if (p.environmentIsStale) 'environment older than its project file',
      if (p.pending > 0) '${p.pending} waiting at the gate',
      if (muted) 'not notified',
      if (!project.canBeActedOn) 'not followed here',
      if (p.following?.unverified ?? false) 'unverified',
    ];
    final counts =
        '${project.running} of ${project.howMuchWork} running'
        '${p.securityClass.isEmpty ? '' : ' · ${p.securityClass}'}';
    // Laid out as Machines and Projects are (walk 10): the project as the page's
    // heading with its menu beside it, a line about it, then its repositories, a card each.
    return Column(
      key: const Key('project-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        // Where this account's following has got, and why it stopped when it did.
        if (p.following case final followed?)
          Wrap(
            spacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                followed.words,
                key: const Key('project-following'),
                style: followed.needsAPerson
                    ? theme.textTheme.bodySmall?.copyWith(color: scheme.error)
                    : theme.textTheme.bodySmall,
              ),
              // Now rather than at the machine's next round, which can be minutes away - after the
              // vault was opened, say, or a push to the project's repository.
              if (checking)
                Text('checking…', key: const Key('project-checking'), style: theme.textTheme.bodySmall)
              else if (onCheck != null && project.canBeActedOn)
                TextButton(key: const Key('project-check-now'), onPressed: onCheck, child: const Text('Check it now')),
            ],
          ),
        if (checked.isNotEmpty)
          Column(
            key: const Key('project-check-said'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[for (final line in checked) Text(line, style: theme.textTheme.bodySmall)],
          ),
        if (workRepositories.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.normal),
          _Repositories(
            repositories: workRepositories,
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

/// A project's repositories, a card each, as machines and projects are listed.
class _Repositories extends StatelessWidget {
  const _Repositories({
    required this.repositories,
    this.onStart,
    this.startUnavailable,
    this.onSync,
    this.onBackups,
    this.onOpens,
    this.onReach,
  });

  final List<Repository> repositories;
  final void Function(String repository)? onStart;
  final String? startUnavailable;
  final void Function(String repository)? onSync;
  final void Function(String repository)? onBackups;
  final void Function(String repository)? onOpens;
  final void Function(String repository)? onReach;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('project-repositories'),
    children: <Widget>[
      for (final repository in repositories)
        _RepositoryLine(
          repository: repository,
          onStart: onStart,
          startUnavailable: startUnavailable,
          onSync: onSync,
          onBackups: onBackups,
          onOpens: onOpens,
          onReach: onReach,
        ),
    ],
  );
}

/// One of a project's repositories, as a project is one in the list of projects: its name, how far
/// it has got, and a menu of what can be done with it, starting work in it first. Its limits are in
/// that menu too, not on the row: not what a day's work needs (walk 10).
class _RepositoryLine extends StatelessWidget {
  const _RepositoryLine({
    required this.repository,
    this.onStart,
    this.startUnavailable,
    this.onSync,
    this.onBackups,
    this.onOpens,
    this.onReach,
  });

  final Repository repository;
  final void Function(String repository)? onStart;
  final String? startUnavailable;
  final void Function(String repository)? onSync;
  final void Function(String repository)? onBackups;
  final void Function(String repository)? onOpens;
  final void Function(String repository)? onReach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = repository.name;
    final state = <String>[
      if (repository.pending > 0) '${repository.pending} waiting at the gate',
      if (repository.behindReason.isNotEmpty) repository.behindWords,
    ].join(' · ');
    PopupMenuItem<VoidCallback> item(String key, String label, void Function(String)? act, {String? whyNot}) =>
        PopupMenuItem<VoidCallback>(
          key: Key(key),
          enabled: act != null && whyNot == null,
          value: act == null ? null : () => act(name),
          child: whyNot == null ? Text(label) : Tooltip(message: whyNot, child: Text(label)),
        );
    return Card(
      child: ListTile(
        key: Key('repository-$name'),
        leading: const Icon(Icons.source_outlined),
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: state.isEmpty
            ? null
            : Text(
                state,
                overflow: TextOverflow.ellipsis,
                style: repository.hasFallenBehind ? TextStyle(color: theme.colorScheme.tertiary) : null,
              ),
        trailing: PopupMenuButton<VoidCallback>(
          key: Key('repository-menu $name'),
          tooltip: 'What can be done with $name',
          icon: const Icon(Icons.more_vert),
          onSelected: (act) => act(),
          itemBuilder: (_) => <PopupMenuEntry<VoidCallback>>[
            item('start-in-$name', 'Start work in $name', onStart, whyNot: startUnavailable),
            const PopupMenuDivider(),
            item('sync-$name', "Ask $name's upstream how far behind it is, now", onSync),
            item('backups-$name', 'Backups of $name', onBackups),
            // A repository's egress is added to the project's, so this is the project's
            // plan and what this repository adds to it: the daemon's reply says which is which.
            item('opens-$name', 'Show what work in $name would open, creating nothing', onOpens),
            item('reach-$name', 'What $name may reach, on top of what the project grants', onReach),
            // A repository's limits replace the project's key by key; the ones it replaced are marked.
            // The rest are never said to be the project's choice: they may be Porelo's.
            if (repository.limits case final limits?) ...<PopupMenuEntry<VoidCallback>>[
              const PopupMenuDivider(),
              PopupMenuItem<VoidCallback>(
                key: Key('limits-$name'),
                enabled: false,
                child: Text('Its limits: ${limits.words}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
