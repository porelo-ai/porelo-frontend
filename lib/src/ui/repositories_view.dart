import 'dart:async';

import 'package:flutter/material.dart';

import '../app/fleet_backend.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/links.dart';
import '../app/machine_binding.dart';
import '../app/project_workspace.dart';
import 'binding_view.dart';
import 'dialog_scroll.dart';
import 'forges_view.dart';
import 'project_forge_view.dart';
import 'tokens.dart';

/// Shows the repositories a person's forge login reaches, connecting first where it has to.
///
/// [machine] checks a project file before it is committed: the machine selected when this opened.
Future<void> showRepositories(
  BuildContext context,
  ForgeConnection forges, {
  FleetBackend? machine,
  String machineName = 'the machine',
  Future<void> Function(String project)? onStartWork,
  VoidCallback? onFollowByAddress,
  List<String> Function(ForgeEntry entry)? usedBy,
  void Function(ForgeRepository repository, Forge forge)? onPick,
}) async {
  if (!forges.connected) unawaited(forges.load());
  await showDialog<void>(
    context: context,
    builder: (_) => RepositoriesDialog(
      forges: forges,
      machine: machine,
      machineName: machineName,
      onStartWork: onStartWork,
      onFollowByAddress: onFollowByAddress,
      usedBy: usedBy,
      onPick: onPick,
    ),
  );
}

/// A person's repositories on a forge: the start of making one a Porelo project.
class RepositoriesDialog extends StatefulWidget {
  /// Constructor taking the connection.
  const RepositoriesDialog({
    required this.forges,
    this.machine,
    this.machineName = 'the machine',
    this.onStartWork,
    this.onFollowByAddress,
    this.usedBy,
    this.onPick,
    super.key,
  });

  /// Where a repository is picked rather than made a project: its line offers it, and picking it
  /// closes the dialog and hands it, with the forge it is on, here.
  final void Function(ForgeRepository repository, Forge forge)? onPick;

  /// Follows a project by its address instead, for a repository no forge set up here holds.
  final VoidCallback? onFollowByAddress;

  /// The repositories of followed projects on a forge, for removing it.
  final List<String> Function(ForgeEntry entry)? usedBy;

  /// Opens the start dialog on the project called by name, on [machine]; null where not offered.
  final Future<void> Function(String project)? onStartWork;

  final ForgeConnection forges;

  /// The machine that checks a project file, or null where none is watched.
  final FleetBackend? machine;

  /// What the person calls it.
  final String machineName;

  @override
  State<RepositoriesDialog> createState() => _RepositoriesDialogState();
}

class _RepositoriesDialogState extends State<RepositoriesDialog> {
  /// The repository chosen, whose next step is shown under it.
  String? _chosen;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        key: const Key('repositories-dialog'),
        title: const Text('Work on a repository you have'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (forges.problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.small),
                    child: Text(
                      forges.problem!,
                      key: const Key('forge-problem'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                // A token kept from before is being tried: not a field that comes and goes.
                if (!forges.connected && (!forges.loaded || forges.busy))
                  Text(
                    forges.current == null
                        ? 'Reading the forges set up on this computer…'
                        : 'Using ${forges.current!.name}, set up on this computer…',
                    key: const Key('forge-kept-token'),
                  )
                else if (forges.connected)
                  ..._list(context, forges, text)
                else if (forges.entries.isEmpty || forges.current != null)
                  ..._connect(context, forges)
                else
                  ..._chooseAForge(context, forges),
                if (widget.onFollowByAddress case final byAddress?)
                  TextButton(
                    key: const Key('follow-by-address'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      byAddress();
                    },
                    child: const Text('Not on a forge? Follow a project by its address'),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('forges-open'),
            onPressed: () => unawaited(showForges(context, forges, usedBy: widget.usedBy)),
            child: const Text('Your forges'),
          ),
          if (forges.connected)
            TextButton(
              key: const Key('forge-forget'),
              onPressed: forges.busy ? null : () => unawaited(forges.forget()),
              child: Text('Remove ${forges.current?.name ?? 'it'} here'),
            ),
          TextButton(
            key: const Key('repositories-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );

  /// Setting up the first forge here, or giving the chosen one a token again.
  List<Widget> _connect(BuildContext context, ForgeConnection forges) => <Widget>[
    Text(
      forges.current == null
          ? 'Which GitHub are your repositories on? Set it up once, with a token: after that, this asks '
                'nothing again.'
          : 'Give ${forges.current!.name} its token again.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    ForgeForm(key: const Key('forge-first'), forges: forges, editing: forges.current, onDone: (_) {}),
  ];

  /// Which forge, where more than one is set up.
  List<Widget> _chooseAForge(BuildContext context, ForgeConnection forges) => <Widget>[
    Text('Which forge are the repositories on?', style: Theme.of(context).textTheme.titleSmall),
    for (final entry in forges.entries)
      ListTile(
        key: ValueKey<String>('forge-choose ${entry.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(entry.name),
        subtitle: Text('${entry.kindWords} · ${entry.address}'),
        onTap: forges.busy ? null : () => unawaited(forges.choose(entry)),
      ),
  ];

  List<Widget> _list(BuildContext context, ForgeConnection forges, TextTheme text) {
    final repositories = forges.repositories;
    final shown = forges.shown;
    return <Widget>[
      // Which forge and which token, said where it cannot be missed, before any repository: one set
      // up long ago was used without a word, with a token older and broader than the person meant
      // (on a rented machine).
      Container(
        key: const Key('forge-in-use'),
        width: double.infinity,
        padding: const EdgeInsets.all(Space.small),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Wrap(
          spacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Forge: ${forges.current?.name ?? forges.forge?.name ?? 'the forge'}'
              '${forges.current == null ? '' : ' (${forges.current!.address})'}, as ${forges.account!.login}',
              key: const Key('forge-account'),
              style: text.titleSmall,
            ),
            TextButton(
              key: const Key('forge-change-token'),
              onPressed: forges.busy ? null : () => unawaited(showForges(context, forges, usedBy: widget.usedBy)),
              child: const Text('Change its token'),
            ),
            TextButton(
              key: const Key('forge-another'),
              onPressed: forges.busy ? null : forges.putAway,
              child: Text(forges.entries.length > 1 ? 'Another forge' : 'Set up another forge'),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.small),
      TextField(
        key: const Key('repositories-search'),
        decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search)),
        onChanged: forges.search,
      ),
      const SizedBox(height: Space.small),
      // GitHub lists what the account has; what the token was narrowed to is only found by asking.
      if (repositories != null && forges.stillAsking > 0)
        Text(
          'Asking GitHub which repositories this token may bind a machine to… '
          '(${forges.stillAsking} still to ask)',
          key: const Key('forge-still-asking'),
          style: text.bodySmall,
        ),
      if (repositories != null && repositories.isNotEmpty)
        SwitchListTile(
          key: const Key('forge-only-bindable'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Only those this token may bind a machine to'),
          subtitle: const Text('Can be slow: GitHub is asked about each repository, one by one.'),
          value: forges.onlyBindable,
          onChanged: forges.showOnlyBindable,
        ),
      if (repositories != null &&
          repositories.isNotEmpty &&
          forges.onlyBindable &&
          forges.stillAsking == 0 &&
          forges.bindable == 0)
        Text(
          'This token may bind a machine to none of them. For each repository you want to make a project '
          'of, it needs Administration and Contents, both read and write: Administration to add a '
          "machine's key, Contents to push the project's configuration.",
          key: const Key('forge-binds-none'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      Text('Choose a repository to see what can be done with it here.', style: text.bodySmall),
      if (repositories == null) const Text('Asking the forge…'),
      if (repositories != null && repositories.isEmpty)
        const Text('This login reaches no repository.', key: Key('no-repositories')),
      if (repositories != null && repositories.isNotEmpty && shown.isEmpty && forges.stillAsking == 0)
        const Text('Nothing matches.', key: Key('no-repository-matches')),
      for (final each in shown) _row(context, forges, each, text),
    ];
  }

  /// Changing the token from a dialog over this one: the forges open, and the dialog goes on with
  /// the forge and a clone reached with the token then in use.
  Future<({Forge forge, ProjectWorkspace workspace})?> Function() _changingTheToken(
    BuildContext context,
    ForgeConnection forges,
    ForgeRepository repository,
  ) => () async {
    await showForges(context, forges, usedBy: widget.usedBy);
    final changed = forges.forge;
    final clone = forges.workspace(repository);
    return changed == null || clone == null ? null : (forge: changed, workspace: clone);
  };

  /// The project's machines and keys at the forge, its changes waiting, and stopping work.
  Future<void> _tools(BuildContext context, ForgeConnection forges, ForgeRepository repository) async {
    final workspace = forges.workspace(repository);
    final machine = widget.machine;
    final forge = forges.forge;
    if (workspace == null || machine == null || forge == null) return;
    await showProjectForge(
      context,
      MachineBinding(forge, workspace, machine, machineName: widget.machineName, login: forges.account?.login ?? ''),
    );
  }

  /// Binds the machine to [repository] from its line, once the token is known to be allowed to;
  /// where it is not, the reason is what shows under the line.
  Future<void> _use(BuildContext context, ForgeConnection forges, ForgeRepository repository) async {
    await _choose(forges, repository);
    if (!context.mounted || forges.mayBind[repository.fullName] != true) return;
    await _bind(context, forges, repository);
  }

  /// Chooses [repository], and asks the forge what it holds and what the token may do there.
  Future<void> _choose(ForgeConnection forges, ForgeRepository repository) async {
    final forge = forges.forge;
    if (forge == null) return;
    setState(() => _chosen = repository.fullName);
    try {
      final has = await forge.hasProjectFile(repository);
      final why = repository.admin ? await forge.whyNoKeys(repository.fullName) : null;
      if (mounted) {
        setState(() {
          forges.isProject[repository.fullName] = has;
          if (repository.admin) forges.heardAbout(repository.fullName, why);
        });
      }
    } on ForgeRefused catch (refused) {
      if (mounted) setState(() => forges.problem = refused.words);
    }
  }

  Future<void> _bind(BuildContext context, ForgeConnection forges, ForgeRepository repository) async {
    final workspace = forges.workspace(repository);
    final machine = widget.machine;
    final forge = forges.forge;
    if (workspace == null || machine == null || forge == null) return;
    final start = widget.onStartWork;
    final project = await showBinding(
      context,
      MachineBinding(forge, workspace, machine, machineName: widget.machineName, login: forges.account?.login ?? ''),
      changeToken: _changingTheToken(context, forges, repository),
      startFollows: start != null,
    );
    // Bound, and asked to start: the start dialog on that project, with this list out of the way.
    if (project != null && start != null && context.mounted) {
      Navigator.of(context).pop();
      await start(project);
    }
  }

  Widget _row(BuildContext context, ForgeConnection forges, ForgeRepository repository, TextTheme text) {
    final isProject = forges.isProject[repository.fullName];
    // A project already: used straight from its line, where the person can bind a machine at all.
    final usable =
        isProject == true &&
        repository.admin &&
        repository.push &&
        widget.machine != null &&
        forges.mayBind[repository.fullName] != false;
    final chosen = _chosen == repository.fullName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          key: ValueKey<String>('repository ${repository.fullName}'),
          dense: true,
          selected: chosen,
          contentPadding: EdgeInsets.zero,
          leading: Icon(repository.private ? Icons.lock_outline : Icons.public, size: Sizes.mark),
          title: Text(repository.fullName),
          subtitle: Text(
            <String>[
              // Binding a machine adds a deploy key, which only an admin may do: said, never found out.
              if (repository.admin)
                'you are an admin'
              else
                'not an admin: no machine can be given keys to it from here',
              if (!repository.push) 'you cannot push to it',
              if (isProject == true) 'has a project.yml',
              if (isProject == false) 'no project.yml yet',
              if (isProject == null) 'looking for a project.yml…',
              if (repository.admin && forges.mayBind[repository.fullName] == false)
                'this token may not give a machine keys to it',
            ].join(' · '),
            style: text.bodySmall,
          ),
          trailing: widget.onPick != null
              ? FilledButton(
                  key: ValueKey<String>('pick ${repository.fullName}'),
                  onPressed: forges.forge == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onPick!(repository, forges.forge!);
                        },
                  child: const Text('Work on it without a project'),
                )
              : usable
              ? FilledButton(
                  key: ValueKey<String>('use-as-project ${repository.fullName}'),
                  onPressed: () => unawaited(_use(context, forges, repository)),
                  child: const Text('Work on it here'),
                )
              : null,
          onTap: forges.forge == null || widget.onPick != null ? null : () => unawaited(_choose(forges, repository)),
        ),
        if (chosen) _next(context, forges, repository, text),
      ],
    );
  }

  /// What can be done with the chosen repository, one step at a time, and why not where it cannot.
  Widget _next(BuildContext context, ForgeConnection forges, ForgeRepository repository, TextTheme text) {
    final isProject = forges.isProject[repository.fullName];
    final mayBind = forges.mayBind[repository.fullName];
    final scheme = Theme.of(context).colorScheme;
    final String says;
    final List<Widget> actions;
    if (widget.machine == null) {
      says = 'No machine is being watched here to work on it.';
      actions = const <Widget>[];
    } else if (!repository.push) {
      says = 'You cannot push to it, so it cannot be made a project from here.';
      actions = const <Widget>[];
    } else if (isProject == null) {
      says = 'Asking ${forges.current?.name ?? 'the forge'} what it holds, and what this token may do there…';
      actions = const <Widget>[];
    } else if (!isProject) {
      // Made a project in its repository, never here (walk 10: the project.yml in the
      // repository is the one place it is written).
      says =
          'It has no project.yml, so it is no Porelo project. Add one in the repository itself; then '
          'choose it again here.';
      actions = const <Widget>[];
    } else {
      says = !repository.admin
          ? 'It is a Porelo project. Only an admin of it can let a machine work on it, since that gives the '
                'machine keys there.'
          : mayBind == false
          ? 'It is a Porelo project, but this token may not give a machine keys to it. Give the token '
                'Administration (read and write) on this repository, then choose it again. '
                '${forges.whyNot[repository.fullName] ?? ''}'
          : 'It is a Porelo project. ${widget.machineName} gets keys of its own for it, and work can '
                'start there.';
      actions = <Widget>[
        // The tools for later, also for a project no machine here follows: a machine that is gone is
        // still removed from what grants it access.
        if (repository.admin)
          TextButton(
            key: ValueKey<String>('repository-tools ${repository.fullName}'),
            onPressed: () => unawaited(_tools(context, forges, repository)),
            child: const Text('Machines that have keys to it'),
          ),
        if (repository.admin && mayBind == false && forges.current != null)
          TextButton(
            key: ValueKey<String>('token-rights ${repository.fullName}'),
            onPressed: () =>
                unawaited(openLink(Uri.parse('https://${forges.current!.address}/settings/personal-access-tokens'))),
            child: const Text('Change the token’s rights'),
          ),
        // Only an admin may add a deploy key, and only with a token that may too.
        if (repository.admin && mayBind == true)
          FilledButton(
            key: ValueKey<String>('bind ${repository.fullName}'),
            onPressed: () => _bind(context, forges, repository),
            child: Text('Work on it on ${widget.machineName}'),
          ),
      ];
    }
    return Container(
      key: ValueKey<String>('repository-next ${repository.fullName}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.small),
      padding: const EdgeInsets.all(Space.small),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(says, key: ValueKey<String>('repository-says ${repository.fullName}')),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.tight),
            Wrap(spacing: Space.tight, children: actions),
          ],
        ],
      ),
    );
  }
}
