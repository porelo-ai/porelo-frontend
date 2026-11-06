import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/default_at_forge.dart';
import '../app/commands.dart';
import '../app/connections.dart' show onTheMachine;
import 'expandable_list_row.dart';
import '../app/fleet_backend.dart';
import '../app/forge.dart';
import '../app/forge_connection.dart';
import '../app/forge_key_check.dart';
import '../app/links.dart';
import '../app/machine_binding.dart';
import '../app/machines.dart';
import '../app/session.dart';
import 'forges_view.dart';
import 'project_forge_view.dart';
import 'filtered_list_section.dart';
import 'command_menu.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// The selected machine, whose vault keeps a forge's token for its Git transfers.
@immutable
class ForgeTokenVault {
  /// Constructor taking the machine, whether it answers and the terminal opener, a stand-in in tests.
  const ForgeTokenVault({required this.machine, required this.answers, this.open});

  /// The machine selected now.
  final Machine machine;

  /// Whether its daemon answers.
  final bool answers;

  /// Opens the terminal the token is typed in.
  final OpenTerminal? open;
}

/// Central forges reached with the person's identity, and host forges reached through tunnels.
class ForgesPage extends StatefulWidget {
  /// Creates the forge list with a separate page for each entry.
  const ForgesPage({
    required this.forges,
    required this.usedBy,
    required this.onOpen,
    this.onMachine,
    this.keyCheck,
    this.tokenVault,
    this.held = const <Connection>[],
    this.heldOn = '',
    this.organizationForge = '',
    super.key,
  });

  /// The configured forges and current access state.
  final ForgeConnection forges;

  /// What the machine [heldOn] declares it connects out with, each by name and source and never with a value.
  final List<Connection> held;

  /// The machine whose declarations [held] are, by name.
  final String heldOn;

  /// The Porelo organization's forge, by host; empty where no organization was read.
  final String organizationForge;

  /// Lists projects using this forge before forgetting it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// Opens this exact item.
  final void Function(ForgeEntry entry) onOpen;

  /// Opens the machine belonging to this item.
  final void Function(String name)? onMachine;

  /// Whether the person's key is listed on their central forge account, absent until supplied.
  final ForgeKeyCheck? keyCheck;

  /// Where a forge's token is stored, absent when no machine answers here.
  final ForgeTokenVault? tokenVault;

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
          if (widget.keyCheck case final check?) ForgeKeyRow(check: check),
          FilteredListSection(
            title: 'My forges',
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
              for (final ListedForge(:address, :entry, :held) in listedForges(forges.allEntries, widget.held))
                if (entry == null)
                  (
                    words: '$address ${_heldWords(held)}',
                    // Only the machine holds it: nothing here asks for a token it already has.
                    child: ItemListRow(
                      key: ValueKey('forges-row held $address'),
                      bodyKey: ValueKey('forge $address'),
                      title: address,
                      subtitle: [_heldWords(held), ?_organizationWords(address)].join(' · '),
                      leading: const Icon(Icons.hub_outlined),
                      onOpen: null,
                      menu: const SizedBox.shrink(),
                    ),
                  )
                else
                  (
                    words: '${entry.name} ${entry.address} ${entry.hostMachine ?? ''}',
                    child: ItemListRow(
                      key: ValueKey('forges-row ${entry.id}'),
                      bodyKey: ValueKey('forge ${entry.name}'),
                      title: entry.name,
                      subtitle: entry.isHost
                          ? 'Through ${entry.hostMachine} · ${entry.browserAddress ?? 'tunnel not reached'}'
                          : [
                              entry.address,
                              entry.authentication == 'ssh' ? 'by SSH key' : 'token chosen explicitly',
                              if (held.isNotEmpty) _heldWords(held),
                              ?_organizationWords(entry.address),
                            ].join(' · '),
                      leading: const Icon(Icons.hub_outlined),
                      onOpen: () => widget.onOpen(entry),
                      menu: forgeMenu(
                        context,
                        forges,
                        entry,
                        widget.usedBy,
                        open: () => widget.onOpen(entry),
                        onMachine: widget.onMachine,
                        tokenVault: widget.tokenVault,
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

  /// Where the machine's credentials for a forge come from, by name and source, and whether each is there now.
  String _heldWords(List<Connection> held) {
    final on = widget.heldOn.isEmpty ? 'the machine' : widget.heldOn;
    return 'declared on $on: ${[for (final each in held) '${each.kindWords} ${each.sourceWords}${each.present ? '' : ' (not there now)'}'].join(', ')}';
  }

  /// Marks the Porelo organization's forge, or null on any other.
  String? _organizationWords(String address) =>
      widget.organizationForge.isNotEmpty && widget.organizationForge.toLowerCase() == address.toLowerCase()
      ? "your Porelo organization's forge"
      : null;
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
  ForgeTokenVault? tokenVault,
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
        id: 'forge.rename',
        label: 'Rename this forge…',
        group: 'Forges',
        home: Home.forgeRow,
        unavailable: forges.busy ? 'Still checking access.' : null,
        run: () => unawaited(showForgeForm(context, forges, editing: entry)),
      ),
      Command(
        id: 'forge.useToken',
        label: 'Use a token instead…',
        group: 'Forges',
        home: Home.forgeRow,
        run: () => unawaited(showForgeForm(context, forges, editing: entry, useToken: true)),
      ),
      Command(
        id: 'forge.storeToken',
        label: 'Store its token in this machine’s vault…',
        group: 'Forges',
        home: Home.forgeRow,
        unavailable: _whyNoTokenStored(entry, tokenVault),
        run: () => unawaited(_storeToken(context, entry, tokenVault)),
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

List<String>? _storeTokenCommand(ForgeEntry entry, Machine machine) => switch (entry.vaultTokenEntry) {
  final name? => onTheMachine(machine, <String>['porelo', 'vault', 'put', name], terminal: true),
  null => null,
};

String? _whyNoTokenStored(ForgeEntry entry, ForgeTokenVault? vault) {
  if (entry.vaultTokenEntry == null) {
    return '“${entry.address}” is no plain server name, so no vault entry can be named for it.';
  }
  if (vault == null) return 'No machine answers here.';
  if (!vault.answers) return '${vault.machine.name} does not answer.';
  if (_storeTokenCommand(entry, vault.machine) == null) {
    return 'No terminal can be opened on ${vault.machine.name} from here.';
  }
  return null;
}

/// Stores the forge's token on the selected machine: typed in a terminal there, and never in a form of this interface.
Future<void> _storeToken(BuildContext context, ForgeEntry entry, ForgeTokenVault? vault) async {
  if (vault == null || _whyNoTokenStored(entry, vault) != null) return;
  final command = _storeTokenCommand(entry, vault.machine);
  if (command == null) return;
  await runInATerminal(
    context,
    title: 'Store the token of ${entry.name} on ${vault.machine.name}',
    explanation:
        'Enter your own forge token at Porelo’s prompt in this terminal. It goes straight to the vault on '
        '${vault.machine.name}, for opening a project and for Git transfers, and never through this program.',
    machine: vault.machine,
    command: command,
    open: vault.open,
  );
}

/// Sets up a forge, or changes [editing], in a dialog of its own; answers what happened, or null.
Future<String?> showForgeForm(
  BuildContext context,
  ForgeConnection forges, {
  ForgeEntry? editing,
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
            ],
          ),
        ),
      ),
    ),
  ),
);

/// A forge's filtered Repositories list.
class ForgePage extends StatefulWidget {
  /// Creates one forge page without prompting for credentials on entry.
  const ForgePage({
    required this.forges,
    required this.usedBy,
    required this.usedOn,
    this.inDefault,
    this.machine,
    this.machineName = 'the machine',
    this.onStartWork,
    this.onOpenProject,
    this.usedOnAt,
    this.onDefaultChanged,
    this.onBack,
    this.onMachine,
    this.tokenVault,
    super.key,
  });

  /// The configured forges and current access state.
  final ForgeConnection forges;

  /// Lists projects using this forge before forgetting it.
  final List<String> Function(ForgeEntry entry) usedBy;

  /// Lists the machines working on a repository.
  final List<String> Function(String fullName) usedOn;

  /// Whether a repository is worked on in the Default project on this machine.
  final bool Function(String fullName)? inDefault;

  /// The machine this item belongs to.
  final FleetBackend? machine;

  /// The display name of the machine an operation targets.
  final String machineName;

  /// Starts work after the backend confirms the project.
  final Future<void> Function(String project)? onStartWork;

  /// Opens a repository's project on its explicitly selected machine.
  final void Function(ForgeEntry entry, String fullName)? onOpenProject;

  /// Lists use on this forge without matching equal names on other forges.
  final List<String> Function(ForgeEntry entry, String fullName)? usedOnAt;

  /// Refreshes the daemon after its default repositories change.
  final VoidCallback? onDefaultChanged;

  /// Returns to the containing list.
  final VoidCallback? onBack;

  /// Opens the machine belonging to this item.
  final void Function(String name)? onMachine;

  /// Where a forge's token is stored, absent when no machine answers here.
  final ForgeTokenVault? tokenVault;

  @override
  State<ForgePage> createState() => _ForgePageState();
}

class _ForgePageState extends State<ForgePage> {
  String? _said;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.forges,
    builder: (context, _) {
      final forges = widget.forges;
      final entry = forges.current;
      return ListView(
        key: ValueKey('forge-page ${entry?.id}'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('My forges'),
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
                  tokenVault: widget.tokenVault,
                  said: (words) => setState(() => _said = words),
                ),
            ],
          ),
          if (entry != null)
            Text(
              '${entry.address} · ${entry.isHost
                  ? 'through the machine connection'
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
            key: ValueKey('forge-repositories ${entry?.id}'),
            title: 'Repositories',
            storageId: 'forge-repositories ${entry?.id}',
            collapsible: true,
            rows: [
              for (final repository in forges.repositories ?? <ForgeRepository>[])
                (words: repository.fullName, child: _row(context, forges, repository)),
            ],
          ),
        ],
      );
    },
  );

  Widget _row(BuildContext context, ForgeConnection forges, ForgeRepository repository) {
    final name = repository.fullName;
    final isProject = forges.isProject[name];
    final entry = forges.current;
    final on = entry == null ? <String>[] : widget.usedOnAt?.call(entry, name) ?? widget.usedOn(name);
    return ItemListRow(
      key: ValueKey('forge-repository $name'),
      bodyKey: ValueKey('repository $name'),
      title: name,
      subtitle: [
        if (on.isNotEmpty) 'a project on ${on.join(', ')}',
        if (repository.push) 'can push' else 'read access',
        if (isProject == true)
          'has a project.yml'
        else if (isProject == false)
          'no project.yml yet'
        else
          'project state unknown',
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
          if (widget.machine != null && forges.connected && repository.push && isProject != true)
            Command(
              id: 'repository.default',
              label: 'Work on it in the Default project',
              group: 'Forges',
              home: Home.forgeRow,
              run: () => unawaited(_act(context, forges, repository, 'default-start')),
            ),
          if (widget.machine != null && widget.inDefault?.call(name) == true)
            Command(
              id: 'repository.defaultRemove',
              label: 'Stop working on it in the Default project',
              group: 'Forges',
              home: Home.forgeRow,
              run: () => unawaited(_act(context, forges, repository, 'default-remove')),
            ),
          Command(
            id: 'repository.tools',
            label: 'Changes waiting…',
            group: 'Forges',
            home: Home.forgeRow,
            unavailable: widget.machine != null && forges.workspace(repository) != null
                ? null
                : 'This needs a connected machine and a working repository adapter.',
            run: () => unawaited(_act(context, forges, repository, 'tools')),
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, ForgeConnection forges, ForgeRepository repository, String chosen) async {
    switch (chosen) {
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

  /// The project's changes waiting at the machine.
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
}

/// Whether the person's key is listed on their central forge account; only a listed key on a good card reads as good.
class ForgeKeyRow extends StatefulWidget {
  /// Reads [check] once shown, and again from the row's menu.
  const ForgeKeyRow({required this.check, super.key});

  /// Core's identity read, reduced to the forge's key check.
  final ForgeKeyCheck check;

  @override
  State<ForgeKeyRow> createState() => _ForgeKeyRowState();
}

class _ForgeKeyRowState extends State<ForgeKeyRow> {
  ForgeKeyReading? _reading;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  void _again() {
    setState(() => _busy = true);
    unawaited(_read());
  }

  Future<void> _read() async {
    final reading = await widget.check.read();
    if (!mounted) return;
    setState(() {
      _reading = reading;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final forge = reading is ForgeKeyAnswered ? reading.forge : null;
    final words = switch (reading) {
      null => 'Checking whether your key is listed on your forge account…',
      ForgeKeyNoIdentity(:final words) => '$words Create your identity in Settings.',
      ForgeKeyUnavailable(:final words) => 'Whether your key is listed is not known. $words',
      ForgeKeyAnswered(forge: null, :final cardProblem) =>
        '${cardProblem == null ? '' : '$cardProblem '}No forge is known yet: no Porelo organization has been read here.',
      ForgeKeyAnswered(forge: final forge?, :final cardProblem) =>
        '${cardProblem == null ? '' : '$cardProblem '}'
            '${switch (forge.listed) {
              ForgeKeyListed.listed => 'Your key is listed on ${forge.login}\'s forge account.',
              ForgeKeyListed.notListed => 'Your key is not listed on ${forge.login}\'s forge account. Add it there.',
              ForgeKeyListed.unknown => 'Whether your key is listed on ${forge.login}\'s forge account could not be asked.',
            }}',
    };
    final good = reading?.good ?? false;
    return ItemListRow(
      key: const Key('forge-key-check'),
      title: 'My key on the forge',
      subtitle: words,
      leading: good
          ? const Icon(Icons.check_circle_outline, key: Key('forge-key-listed'))
          : const Icon(Icons.key_outlined, key: Key('forge-key-not-good')),
      onOpen: null,
      menu: CommandMenu(
        key: const Key('forge-key-menu'),
        tooltip: 'My key on the forge',
        commands: [
          Command(
            id: 'forge.keyAdd',
            label: 'Add my key on the forge…',
            group: 'Forges',
            home: Home.forgeRow,
            run: () => unawaited(openLink(forge!.accountUrl)),
            unavailable: forge == null ? 'No forge is known yet.' : null,
          ),
          Command(
            id: 'forge.keyList',
            label: 'See the keys the forge lists',
            group: 'Forges',
            home: Home.forgeRow,
            run: () => unawaited(openLink(forge!.keysUrl)),
            unavailable: forge == null ? 'No forge is known yet.' : null,
          ),
          Command(
            id: 'forge.keyCheck',
            label: 'Check again',
            group: 'Forges',
            home: Home.forgeRow,
            run: _again,
            unavailable: _busy ? 'Still checking.' : null,
          ),
        ],
      ),
    );
  }
}
