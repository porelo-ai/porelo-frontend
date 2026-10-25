import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/default_at_forge.dart';
import '../app/commands.dart';
import 'expandable_list_row.dart';
import '../app/fleet_backend.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/links.dart';
import '../app/machine_binding.dart';
import '../app/machines.dart';
import '../app/project_workspace.dart';
import 'binding_view.dart';
import 'forges_view.dart';
import 'project_forge_view.dart';
import 'tokens.dart';

/// Every forge set up on this computer, laid out as Machines and Projects are: added here, changed or
/// removed from each one's menu, and opened to its repositories (walk 10: the git
/// providers configured apart, under a place of their own).
class ForgesPage extends StatefulWidget {
  /// Constructor taking the forges, what uses each, and what opening one does.
  const ForgesPage({required this.forges, required this.usedBy, required this.onOpen, super.key});

  /// The forges set up here, and the one being looked at.
  final ForgeConnection forges;

  /// The repositories of followed projects on a forge, for removing it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// Opens one forge's repositories.
  final void Function(ForgeEntry entry) onOpen;

  @override
  State<ForgesPage> createState() => _ForgesPageState();
}

class _ForgesPageState extends State<ForgesPage> {
  String? _said;

  @override
  void initState() {
    super.initState();
    // Read again each time: a token kept before the list existed, or another window's change, shows.
    // After the first frame: reading tells its listeners, and this page is built by one of them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.forges.readList());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      final text = Theme.of(context).textTheme;
      return ListView(
        key: const Key('forges-page'),
        padding: const EdgeInsets.all(Space.normal),
        children: <Widget>[
          Wrap(
            spacing: Space.normal,
            runSpacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Forges', style: text.headlineSmall),
              FilledButton.icon(
                key: const Key('forge-add'),
                onPressed: forges.busy ? null : () => unawaited(_form(context)),
                icon: const Icon(Icons.add, size: Sizes.rowIcon),
                label: const Text('Add a forge'),
              ),
            ],
          ),
          const SizedBox(height: Space.tight),
          Text(
            'Where your repositories are, each reached with a token kept in this computer’s keychain.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Space.normal),
          if (forges.problem != null)
            Text(
              forges.problem!,
              key: const Key('forges-problem'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_said != null) Text(_said!, key: const Key('forges-said')),
          if (forges.loaded && forges.entries.isEmpty) const Text('None yet.', key: Key('forges-none')),
          for (final entry in forges.entries) _row(context, forges, entry),
        ],
      );
    },
  );

  Widget _row(BuildContext context, ForgeConnection forges, ForgeEntry entry) {
    final mine = forges.current?.id == entry.id && forges.connected;
    final count = mine ? forges.repositories?.length : null;
    final open = listOpenCommand(label: 'Open forge', home: Home.forgeRow, open: () => widget.onOpen(entry));
    return ExpandableListRow(
      key: ValueKey<String>('forges-row ${entry.name}'),
      bodyKey: ValueKey<String>('forge ${entry.name}'),
      leading: Icon(mine ? Icons.hub : Icons.hub_outlined),
      selected: mine,
      title: entry.name,
      state: mine ? 'Connected' : 'Configured',
      primary: open,
      onOpen: open.run,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            <String>[
              entry.kindWords,
              entry.address,
              if (mine) 'as ${forges.account!.login}',
              if (count != null) count == 1 ? '1 repository' : '$count repositories',
            ].join('  ·  '),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              forgeMenu(context, forges, entry, widget.usedBy, said: (words) => setState(() => _said = words)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _form(BuildContext context) async {
    final said = await showForgeForm(context, widget.forges);
    if (said != null && said.isNotEmpty && mounted) setState(() => _said = said);
  }
}

/// A forge's menu, on its card and beside its page's heading: a new token or name, or removing it.
Widget forgeMenu(
  BuildContext context,
  ForgeConnection forges,
  ForgeEntry entry,
  List<String> Function(ForgeEntry entry) usedBy, {
  required void Function(String said) said,
}) {
  final commands = forgeRowCommands(
    name: entry.name,
    busy: forges.busy,
    change: () => unawaited(() async {
      final words = await showForgeForm(context, forges, editing: entry);
      if (words != null && words.isNotEmpty) said(words);
    }()),
    remove: () => unawaited(() async {
      final words = await removeForge(context, forges, entry, usedBy(entry));
      if (words != null) said(words);
    }()),
  );
  return PopupMenuButton<String>(
    key: ValueKey<String>('forges-menu ${entry.name}'),
    tooltip: 'What can be done with ${entry.name}',
    onSelected: (id) {
      final command = commands.firstWhere((command) => command.id == id);
      if (command.available) command.run();
    },
    itemBuilder: (_) => [
      for (final command in commands)
        PopupMenuItem<String>(
          key: ValueKey<String>('forge-${command.id} ${entry.name}'),
          value: command.id,
          enabled: command.available,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(command.label),
            subtitle: command.unavailable == null ? null : Text(command.unavailable!),
          ),
        ),
    ],
  );
}

/// Sets up a forge, or changes [editing], in a dialog of its own; answers what happened, or null.
Future<String?> showForgeForm(
  BuildContext context,
  ForgeConnection forges, {
  ForgeEntry? editing,
  VoidCallback? onFollowByAddress,
}) => showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('forge-form-dialog'),
    title: Text(editing == null ? 'Add a forge' : 'Change ${editing.name}'),
    content: SizedBox(
      width: Sizes.dialog,
      child: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: forges,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (forges.problem != null)
                Text(
                  forges.problem!,
                  key: const Key('forge-problem'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ForgeForm(
                key: Key(editing == null ? 'forge-add-form' : 'forge-edit ${editing.id}'),
                forges: forges,
                editing: editing,
                onDone: (said) => Navigator.of(context).pop(said),
              ),
              // A repository on no forge is followed by its address instead.
              if (onFollowByAddress != null)
                TextButton(
                  key: const Key('follow-by-address'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onFollowByAddress();
                  },
                  child: const Text('Not on a forge? Follow a project by its address'),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// One forge's repositories, as a page: filtered from the top, a card each with what can be done with
/// it in its menu, and on which watched machines it is worked on.
class ForgePage extends StatefulWidget {
  /// Constructor taking the connection, the machine bound to, and where each repository is used.
  const ForgePage({
    required this.forges,
    required this.usedBy,
    required this.usedOn,
    this.inDefault,
    this.machine,
    this.terminalMachine,
    this.machineName = 'the machine',
    this.onStartWork,
    this.onFollowByAddress,
    this.onDefaultChanged,
    super.key,
  });

  /// The forges set up here, and the one being looked at.
  final ForgeConnection forges;

  /// The repositories of followed projects on a forge, for removing it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// The watched machines a repository is worked on, by its full name.
  final List<String> Function(String fullName) usedOn;

  /// Whether a repository, by its full name, is worked on without a project on [machine].
  final bool Function(String fullName)? inDefault;

  /// The machine a repository is bound to, or null where none is watched.
  final FleetBackend? machine;

  /// Where the binding’s token prompt runs.
  final Machine? terminalMachine;

  /// What the person calls it.
  final String machineName;

  /// Opens the start dialog on the project called by name, once a binding asked for it.
  final Future<void> Function(String project)? onStartWork;

  /// Follows a project by its address instead, for a repository no forge holds.
  final VoidCallback? onFollowByAddress;

  /// Called once a repository went into `default` or out of it, so the machine is asked again.
  final VoidCallback? onDefaultChanged;

  @override
  State<ForgePage> createState() => _ForgePageState();
}

class _ForgePageState extends State<ForgePage> {
  String? _chosen;
  String? _said;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final entry = forges.current;
      final repositories = forges.repositories;
      final shown = forges.shown;
      return ListView(
        key: const Key('forge-page'),
        padding: const EdgeInsets.all(Space.normal),
        children: <Widget>[
          Wrap(
            spacing: Space.normal,
            runSpacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(entry?.name ?? 'Forge', key: const Key('forge-title'), style: text.headlineSmall),
              if (entry != null)
                forgeMenu(context, forges, entry, widget.usedBy, said: (words) => setState(() => _said = words)),
            ],
          ),
          const SizedBox(height: Space.tight),
          if (entry != null)
            Text(
              <String>[entry.address, if (forges.connected) 'as ${forges.account!.login}'].join('  ·  '),
              key: const Key('forge-account'),
              style: text.bodySmall,
            ),
          const SizedBox(height: Space.small),
          if (forges.problem != null)
            Text(
              forges.problem!,
              key: const Key('forge-problem'),
              style: TextStyle(color: scheme.error),
            ),
          if (_said != null) Text(_said!, key: const Key('forge-said')),
          // Loading is shown as loading: an empty page read as a fault until the list came (walk 10).
          if (forges.busy || !forges.loaded || (forges.connected && repositories == null))
            Padding(
              key: const Key('forge-loading'),
              padding: const EdgeInsets.symmetric(vertical: Space.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const LinearProgressIndicator(),
                  const SizedBox(height: Space.tight),
                  Text('Reading your repositories at ${entry?.name ?? 'the forge'}…', style: text.bodySmall),
                ],
              ),
            ),
          if (!forges.connected && (!forges.loaded || forges.busy))
            Text(
              entry == null
                  ? 'Reading the forges set up on this computer…'
                  : 'Using ${entry.name}, set up on this computer…',
              key: const Key('forge-kept-token'),
            )
          else if (!forges.connected)
            ForgeForm(key: const Key('forge-first'), forges: forges, editing: entry, onDone: (_) {}, cancels: false)
          else ...<Widget>[
            TextField(
              key: const Key('repositories-search'),
              decoration: const InputDecoration(labelText: 'Filter', prefixIcon: Icon(Icons.search)),
              onChanged: forges.search,
            ),
            const SizedBox(height: Space.small),
            if (repositories != null && repositories.isEmpty)
              const Text('This login reaches no repository.', key: Key('no-repositories')),
            if (repositories != null && repositories.isNotEmpty && shown.isEmpty)
              const Text('Nothing matches.', key: Key('no-repository-matches')),
            for (final each in shown) _row(context, forges, each, text),
          ],
          if (widget.onFollowByAddress case final byAddress?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('follow-by-address'),
                onPressed: byAddress,
                child: const Text('Not on a forge? Follow a project by its address'),
              ),
            ),
        ],
      );
    },
  );

  Widget _row(BuildContext context, ForgeConnection forges, ForgeRepository repository, TextTheme text) {
    final name = repository.fullName;
    final isProject = forges.isProject[name];
    final on = widget.usedOn(name);
    final chosen = _chosen == name;
    return Card(
      key: ValueKey<String>('forge-repository $name'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            key: ValueKey<String>('repository $name'),
            selected: chosen,
            leading: Icon(repository.private ? Icons.lock_outline : Icons.public),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  <String>[
                    // Access is the person’s, without requiring repository administration.
                    if (repository.push) 'you can push to it' else 'you cannot push to it',
                    if (isProject == true) 'has a project.yml',
                    if (isProject == false) 'no project.yml yet',
                    if (isProject == null) 'looking for a project.yml…',
                  ].join(' · '),
                  style: text.bodySmall,
                ),
                // Where it is worked on, by the machines watched here: their names, nothing else
                // (walk 10).
                if (on.isNotEmpty) ...<Widget>[
                  Text('  ·  on ${on.length} machine${on.length == 1 ? '' : 's'} ', style: text.bodySmall),
                  Tooltip(
                    key: ValueKey<String>('repository-machines $name'),
                    message: on.join('\n'),
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: Sizes.mark),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              key: ValueKey<String>('forge-repository-menu $name'),
              tooltip: 'What can be done with $name',
              onOpened: () => unawaited(_choose(forges, repository)),
              onSelected: (chosen) => unawaited(_act(context, forges, repository, chosen)),
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                // Only where the person can push the signed machine-signers commit.
                if (widget.machine != null && repository.push && isProject != false)
                  PopupMenuItem<String>(
                    key: ValueKey<String>('bind $name'),
                    value: 'bind',
                    child: Text('Work on it on ${widget.machineName}'),
                  ),
                // Default's one task, where the repository is seen (walk 10).
                if (widget.machine != null && repository.push && isProject != true)
                  widget.inDefault?.call(name) ?? false
                      ? PopupMenuItem<String>(
                          key: ValueKey<String>('default-remove $name'),
                          value: 'default-remove',
                          child: Text('No longer work on it without a project on ${widget.machineName}'),
                        )
                      : PopupMenuItem<String>(
                          key: ValueKey<String>('default-add $name'),
                          value: 'default-add',
                          child: Text('Work on it without a project on ${widget.machineName}'),
                        ),
                if (repository.push)
                  PopupMenuItem<String>(
                    key: ValueKey<String>('repository-tools $name'),
                    value: 'tools',
                    child: const Text('Machines whose messages it trusts'),
                  ),
                PopupMenuItem<String>(
                  key: ValueKey<String>('open-at-forge $name'),
                  value: 'open',
                  child: const Text('Open it at the forge'),
                ),
              ],
            ),
            onTap: () => unawaited(_choose(forges, repository)),
          ),
          if (chosen) _says(context, forges, repository),
        ],
      ),
    );
  }

  /// What the chosen repository is, and why a machine cannot work on it where it cannot.
  Widget _says(BuildContext context, ForgeConnection forges, ForgeRepository repository) {
    final name = repository.fullName;
    final isProject = forges.isProject[name];
    final says = widget.machine == null
        ? 'No machine is being watched here to work on it.'
        : !repository.push
        ? 'You cannot push to it, so no machine can be set up to work on it from here.'
        : isProject == null
        ? 'Asking ${forges.current?.name ?? 'the forge'} what it holds, and what this token may do there…'
        : !isProject
        // Made a project in its repository, never here (walk 10).
        ? 'It has no project.yml, so it is no Porelo project. Add one in the repository itself.'
        : 'It is a Porelo project. ${widget.machineName} uses your own token in its vault, and work can start there.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
      child: Text(says, key: ValueKey<String>('repository-says $name'), style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Future<void> _act(BuildContext context, ForgeConnection forges, ForgeRepository repository, String chosen) async {
    switch (chosen) {
      case 'bind':
        await _choose(forges, repository);
        if (!context.mounted || forges.isProject[repository.fullName] != true) return;
        if (!repository.push) return;
        await _bind(context, forges, repository);
      case 'tools':
        await _tools(context, forges, repository);
      case 'default-add' || 'default-remove':
        final machine = widget.machine;
        final forge = forges.forge;
        if (machine == null || forge == null) return;
        final helper = DefaultAtForge(machine, machineName: widget.machineName);
        try {
          final said = chosen == 'default-add' ? await helper.add(repository) : await helper.remove(repository);
          if (mounted) setState(() => _said = said);
        } on ForgeRefused catch (refused) {
          if (mounted) setState(() => forges.problem = refused.words);
        } on VarlinkException catch (refusal) {
          if (mounted) {
            setState(
              () => _said = '${widget.machineName} refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.',
            );
          }
        }
        widget.onDefaultChanged?.call();
      case 'rights':
        await openLink(Uri.parse('https://${forges.current!.address}/settings/personal-access-tokens'));
      case 'open':
        await openLink(Uri.parse('https://${forges.current?.address ?? 'github.com'}/${repository.fullName}'));
    }
  }

  /// Chooses [repository], and asks the forge what it holds and what the token may do there.
  Future<void> _choose(ForgeConnection forges, ForgeRepository repository) async {
    final forge = forges.forge;
    if (forge == null) return;
    setState(() => _chosen = repository.fullName);
    try {
      final has = await forge.hasProjectFile(repository);
      if (mounted) {
        setState(() {
          forges.isProject[repository.fullName] = has;
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
      terminalMachine: widget.terminalMachine,
      openTerminal: forges.openTerminal,
    );
    if (project != null && start != null && context.mounted) await start(project);
  }

  /// The project's machines and keys at the forge.
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

  /// Changing the token from a dialog over the binding: the binding goes on with the token then in use.
  Future<({Forge forge, ProjectWorkspace workspace})?> Function() _changingTheToken(
    BuildContext context,
    ForgeConnection forges,
    ForgeRepository repository,
  ) => () async {
    final entry = forges.current;
    if (entry != null) await showForgeForm(context, forges, editing: entry);
    final changed = forges.forge;
    final clone = forges.workspace(repository);
    return changed == null || clone == null ? null : (forge: changed, workspace: clone);
  };
}
