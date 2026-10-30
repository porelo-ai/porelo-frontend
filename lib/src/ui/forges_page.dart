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
import 'filtered_list_section.dart';
import 'registry_persons.dart';
import '../app/registry_pages.dart';
import 'command_menu.dart';
import 'tokens.dart';

/// Central forges reached with the person's identity, and host forges reached through tunnels.
class ForgesPage extends StatefulWidget {
  /// Creates the forge list with a separate page for each entry.
  const ForgesPage({required this.forges, required this.usedBy, required this.onOpen, this.onMachine, super.key});

  /// The configured forges and current access state.
  final ForgeConnection forges;

  /// Lists projects using this forge before forgetting it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// Opens this exact item.
  final void Function(ForgeEntry entry) onOpen;

  /// Opens the machine belonging to this item.
  final void Function(String name)? onMachine;
  @override
  State<ForgesPage> createState() => _ForgesPageState();
}

class _ForgesPageState extends State<ForgesPage> {
  String? _said;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.forges.readList());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      return ListView(
        key: const Key('forges-page'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          if (forges.problem case final problem?) Text(problem, key: const Key('forges-problem')),
          if (_said case final said?) Text(said),
          FilteredListSection(
            title: 'Forges',
            storageId: 'forges',
            actions: [
              FilledButton.icon(
                key: const Key('forge-add'),
                onPressed: forges.busy ? null : () => unawaited(showForgeForm(context, forges)),
                icon: const Icon(Icons.add),
                label: const Text('Connect a forge…'),
              ),
            ],
            rows: [
              for (final entry in forges.allEntries)
                (
                  words: '${entry.name} ${entry.address} ${entry.hostMachine ?? ''}',
                  child: ItemListRow(
                    key: ValueKey('forges-row ${entry.id}'),
                    bodyKey: ValueKey('forge ${entry.name}'),
                    title: entry.name,
                    subtitle: entry.isHost
                        ? 'Through ${entry.hostMachine} · ${entry.browserAddress ?? 'tunnel not reached'}'
                        : '${entry.address} · ${entry.authentication == 'ssh' ? 'by SSH key' : 'token chosen explicitly'}',
                    leading: const Icon(Icons.hub_outlined),
                    onOpen: () => widget.onOpen(entry),
                    menu: forgeMenu(
                      context,
                      forges,
                      entry,
                      widget.usedBy,
                      open: () => widget.onOpen(entry),
                      onMachine: widget.onMachine,
                      said: (words) => setState(() => _said = words),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// The forge's own operations, with token entry offered only as an explicit terminal alternative.
Widget forgeMenu(
  BuildContext context,
  ForgeConnection forges,
  ForgeEntry entry,
  List<String> Function(ForgeEntry entry) usedBy, {
  required void Function(String said) said,
  VoidCallback? open,
  void Function(String name)? onMachine,
}) {
  final commands = <Command>[
    if (open != null) listOpenCommand(label: 'Open the forge', home: Home.forgeRow, open: open),
    Command(
      id: 'forge.checkAccess',
      label: 'Check my access',
      group: 'Forges',
      home: Home.forgeRow,
      run: () => unawaited(forges.choose(entry)),
      unavailable: forges.busy ? 'Still checking access.' : null,
    ),
    if (entry.isHost) ...[
      Command(
        id: 'forge.browser',
        label: 'Open in the browser',
        group: 'Forges',
        home: Home.forgeRow,
        unavailable: entry.browserAddress == null ? 'The tunnel has not confirmed an address.' : null,
        run: () {
          if (entry.browserAddress case final address?) unawaited(openLink(address));
        },
      ),
      Command(
        id: 'forge.machine',
        label: 'Open the machine',
        group: 'Forges',
        home: Home.forgeRow,
        run: () => onMachine?.call(entry.hostMachine!),
        unavailable: onMachine == null ? 'The machine is not watched here.' : null,
      ),
    ] else ...[
      Command(
        id: 'forge.useToken',
        label: 'Use a token instead…',
        group: 'Forges',
        home: Home.forgeRow,
        run: () => unawaited(showForgeForm(context, forges, editing: entry, useToken: true)),
      ),
      Command(
        id: 'forge.remove',
        label: 'Forget this forge…',
        group: 'Forges',
        home: Home.forgeRow,
        run: () => unawaited(() async {
          final words = await removeForge(context, forges, entry, usedBy(entry));
          if (words != null) said(words);
        }()),
      ),
    ],
  ];
  return CommandMenu(
    key: ValueKey('forges-menu ${entry.name}'),
    commands: commands,
    tooltip: 'What can be done with ${entry.name}',
  );
}

/// Sets up a forge, or changes [editing], in a dialog of its own; answers what happened, or null.
Future<String?> showForgeForm(
  BuildContext context,
  ForgeConnection forges, {
  ForgeEntry? editing,
  VoidCallback? onFollowByAddress,
  bool useToken = false,
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
                useToken: useToken,
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

/// A forge's independently filtered Registry and Repositories lists.
class ForgePage extends StatefulWidget {
  /// Creates one forge page without prompting for credentials on entry.
  const ForgePage({
    required this.forges,
    required this.usedBy,
    required this.usedOn,
    this.inDefault,
    this.machine,
    this.terminalMachine,
    this.machineName = 'the machine',
    this.onStartWork,
    this.onOpenProject,
    this.usedOnAt,
    this.onFollowByAddress,
    this.onDefaultChanged,
    this.onBack,
    this.onMachine,
    this.registry,
    super.key,
  });

  /// The configured forges and current access state.
  final ForgeConnection forges;

  /// Lists projects using this forge before forgetting it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// Lists the machines working on a repository.
  final List<String> Function(String fullName) usedOn;

  /// Whether a repository is worked on without a project on this machine.
  final bool Function(String fullName)? inDefault;

  /// The machine this item belongs to.
  final FleetBackend? machine;

  /// The machine where repository credential prompts run.
  final Machine? terminalMachine;

  /// The display name of the machine an operation targets.
  final String machineName;

  /// Starts work after the backend confirms the project.
  final Future<void> Function(String project)? onStartWork;

  /// Opens a followed repository on its explicitly selected machine and project.
  final void Function(ForgeEntry entry, String fullName)? onOpenProject;

  /// Lists use on this forge without matching equal names on other forges.
  final List<String> Function(ForgeEntry entry, String fullName)? usedOnAt;

  /// Opens following a repository by its address.
  final VoidCallback? onFollowByAddress;

  /// Refreshes the daemon after its default repositories change.
  final VoidCallback? onDefaultChanged;

  /// Returns to the containing list.
  final VoidCallback? onBack;

  /// Opens the machine belonging to this item.
  final void Function(String name)? onMachine;

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages? registry;
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
      final entry = forges.current;
      final registry = widget.registry;
      return ListView(
        key: ValueKey('forge-page ${entry?.id}'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Forges'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry?.name ?? 'Forge',
                  key: const Key('forge-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (entry != null)
                forgeMenu(
                  context,
                  forges,
                  entry,
                  widget.usedBy,
                  onMachine: widget.onMachine,
                  said: (words) => setState(() => _said = words),
                ),
            ],
          ),
          if (entry != null)
            Text(
              '${entry.address} · ${entry.isHost
                  ? 'through the host tunnel'
                  : entry.authentication == 'ssh'
                  ? 'by SSH key'
                  : 'token chosen explicitly'}'
              '${forges.account == null ? '' : ' · login ${forges.account!.login}'}',
              key: const Key('forge-account'),
            ),
          if (forges.problem case final problem?) Text(problem, key: const Key('forge-problem')),
          if (_said case final said?) Text(said, key: const Key('forge-said')),
          if (forges.busy) const LinearProgressIndicator(key: Key('forge-loading')),
          if (!forges.connected && !forges.busy)
            const Text('Access has not been confirmed. Check my access from the menu.'),
          FilteredListSection(
            key: ValueKey('forge-registry ${entry?.id}'),
            title: 'Registry',
            storageId: 'forge-registry ${entry?.id}',
            collapsible: true,
            rows: [
              for (final row in forges.registryRows)
                if (row.forgeId == entry?.id)
                  (
                    words: row.name,
                    child: ItemListRow(
                      title: row.name,
                      subtitle: '${row.persons ?? 'unknown'} persons · ${row.machines ?? 'unknown'} machines',
                      leading: const Icon(Icons.folder_shared_outlined),
                      onOpen: registry == null ? null : () => unawaited(registry.refresh()),
                      menu: CommandMenu(
                        tooltip: 'Registry ${row.name}',
                        commands: [
                          if (registry != null)
                            if (registry.item(row.target) case final item?)
                              ...registryItemCommands(context, registry, item, [
                                RegistryOperation.refresh,
                                RegistryOperation.fileCard,
                                RegistryOperation.selectRegistry,
                                RegistryOperation.createRegistry,
                              ]),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          if (registry?.problem case final problem?) Text(problem),
          if (forges.registryRows.isEmpty) const Text('Verified registry state has not been supplied.'),
          FilteredListSection(
            key: ValueKey('forge-repositories ${entry?.id}'),
            title: 'Repositories',
            storageId: 'forge-repositories ${entry?.id}',
            collapsible: true,
            rows: [
              for (final repository in forges.repositories ?? <ForgeRepository>[])
                (words: repository.fullName, child: _row(context, forges, repository)),
            ],
          ),
          if (widget.onFollowByAddress case final follow?)
            TextButton(onPressed: follow, child: const Text('Follow a project by its address')),
        ],
      );
    },
  );

  Widget _row(BuildContext context, ForgeConnection forges, ForgeRepository repository) {
    final name = repository.fullName;
    final isProject = forges.isProject[name];
    final entry = forges.current;
    final on = entry == null ? <String>[] : widget.usedOnAt?.call(entry, name) ?? widget.usedOn(name);
    final canBind =
        widget.machine != null && repository.push && forges.workspace(repository) != null && isProject == true;
    return ItemListRow(
      key: ValueKey('forge-repository $name'),
      bodyKey: ValueKey('repository $name'),
      title: name,
      subtitle: [
        if (on.isNotEmpty) 'followed on ${on.join(', ')}',
        if (repository.push) 'can push' else 'read access',
        if (isProject == true) 'has a project.yml' else if (isProject == null) 'project state unknown',
        if (_chosen == name && forges.problem != null) forges.problem!,
      ].join(' · '),
      leading: Icon(repository.private ? Icons.lock_outline : Icons.public),
      onOpen: on.isNotEmpty && widget.onOpenProject != null
          ? () => widget.onOpenProject!(entry!, name)
          : () => unawaited(_act(context, forges, repository, 'open')),
      menu: CommandMenu(
        key: ValueKey('forge-repository-menu $name'),
        tooltip: 'What can be done with $name',
        commands: [
          if (on.isNotEmpty)
            Command(
              id: 'repository.project',
              label: 'Open the project',
              group: 'Forges',
              home: Home.forgeRow,
              unavailable: widget.onOpenProject == null ? 'The project is not watched in this window.' : null,
              run: () => widget.onOpenProject?.call(entry!, name),
            ),
          Command(
            id: 'repository.open',
            label: 'Open it at the forge',
            group: 'Forges',
            home: Home.forgeRow,
            run: () => unawaited(_act(context, forges, repository, 'open')),
          ),
          Command(
            id: 'repository.follow',
            label: 'Follow it as a project…',
            group: 'Forges',
            home: Home.forgeRow,
            unavailable: canBind ? null : 'Following needs confirmed project access and a working repository adapter.',
            run: () => unawaited(_act(context, forges, repository, 'bind')),
          ),
          if (widget.machine != null && forges.connected && repository.push && isProject != true)
            Command(
              id: 'repository.default',
              label: 'Work on it without a project',
              group: 'Forges',
              home: Home.forgeRow,
              run: () => unawaited(_act(context, forges, repository, 'default-start')),
            ),
        ],
      ),
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
      case 'default-start':
        final machine = widget.machine;
        final start = widget.onStartWork;
        if (machine == null || !forges.connected) return;
        try {
          await DefaultAtForge(machine, machineName: widget.machineName).add(repository);
          widget.onDefaultChanged?.call();
          if (mounted && start != null) await start(defaultProject);
        } on ForgeRefused catch (refused) {
          if (mounted) setState(() => _said = refused.words);
        } on VarlinkException catch (refused) {
          if (mounted) setState(() => _said = 'The machine refused it: ${refused.simpleName}.');
        }
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
        final base = forges.current?.browserAddress;
        if (base != null && RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository.fullName)) {
          await openLink(base.replace(path: '/${repository.fullName}'));
        }
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
    if (entry != null) await showForgeForm(context, forges, editing: entry, useToken: true);
    final changed = forges.forge;
    final clone = forges.workspace(repository);
    return changed == null || clone == null ? null : (forge: changed, workspace: clone);
  };
}
