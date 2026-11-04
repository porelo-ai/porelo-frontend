import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart' show defaultProject;
import 'package:porelo_host/porelo_host.dart' show checkedEd25519, isUsableHostAddress;

import '../app/commands.dart';
import '../app/host_progress.dart';
import '../app/key_recovery.dart' show BackupScope;
import '../app/organization_source.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'key_recovery_dialog.dart';
import 'organization_dialogs.dart';
import 'organization_token_words.dart';
import 'tokens.dart';

String _reach(OrganizationHost host) {
  final address = host.address;
  if (address == null) return 'no address yet';
  if (host.port == null) return address;
  return address.contains(':') ? '[$address]:${host.port}' : '$address:${host.port}';
}

class _Problem extends StatelessWidget {
  const _Problem(this.words);

  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.small),
    child: Text(words, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

/// Why [host] cannot be connected to now, or null where it can.
String? _whyNotConnect(OrganizationHost host, HostConnections? connections) => connections == null
    ? 'This computer has no way to connect yet.'
    : host.address == null
    ? 'Its Machine Admin has not entered its address yet.'
    : null;

/// One machine of the organization under its heading *Machines*: what it is, *Connect* for a person with an account
/// there while not connected, and its one menu.
class OrganizationMachineRow extends StatefulWidget {
  /// Shows [host] to the person [view] reads for.
  const OrganizationMachineRow({
    required this.view,
    required this.host,
    required this.connections,
    required this.onOpen,
    this.commands = const [],
    this.words,
    super.key,
  });

  /// What the organization says now.
  final OrganizationView view;

  /// The machine.
  final OrganizationHost host;

  /// This person's connections, absent where this computer has none to make.
  final HostConnections? connections;

  /// Opens its page.
  final VoidCallback onOpen;

  /// What its ⋮ holds for this person.
  final List<Command> commands;

  /// What the organization says of it, ahead of the person's own standing there.
  final String? words;

  @override
  State<OrganizationMachineRow> createState() => _OrganizationMachineRowState();
}

class _OrganizationMachineRowState extends State<OrganizationMachineRow> {
  bool _connecting = false;
  String? _refusal;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _refusal = null;
    });
    String? refusal;
    try {
      await widget.connections!.connect(widget.host.name);
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _refusal = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final view = widget.view;
    final connected = widget.connections?.up(host.name) ?? false;
    final why = _whyNotConnect(host, widget.connections);
    // The right to connect is an account there, and that is what the person's own list of machines says.
    final hasAccount = view.myHosts.any((each) => each.name == host.name);
    final mine = [
      for (final project in view.projects)
        if (project.host == host.name && (project.admins.contains(view.me) || project.members.contains(view.me)))
          project.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: ValueKey('my-host ${host.name}'),
          leading: const Icon(Icons.dns_outlined),
          title: Text(host.name),
          subtitle: Text(
            [
              ?widget.words,
              if (host.admins.contains(view.me)) 'you administer it',
              if (mine.isNotEmpty) 'your projects: ${mine.join(', ')}',
              if (connected) mine.isEmpty ? 'connected' : 'connected, ready to work on' else why ?? 'not connected yet',
            ].join(' · '),
          ),
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.small,
            children: [
              if (hasAccount && !connected)
                FilledButton(
                  key: ValueKey('organization.connect/${host.name}'),
                  onPressed: why != null || _connecting ? null : () => unawaited(_connect()),
                  child: const Text('Connect'),
                ),
              if (widget.commands.isNotEmpty)
                CommandMenu(commands: widget.commands, tooltip: 'What can be done with ${host.name}'),
            ],
          ),
          onTap: widget.onOpen,
        ),
        if (_refusal case final refusal?) _Problem(refusal),
      ],
    );
  }
}

/// One host: how it is reached, the projects it carries and its host admins, changed by its host admins alone, and the
/// person's own connection to it.
class OrganizationHostPage extends StatefulWidget {
  /// Reads [host] from [organization].
  const OrganizationHostPage({
    required this.organization,
    required this.host,
    this.refresh = 0,
    required this.onBack,
    this.connections,
    this.onGiveToken,
    this.onStartWork,
    this.keys,
    this.work,
    super.key,
  });

  /// The organization.
  final Organization organization;

  /// This person's connections, absent where this computer has none to make.
  final HostConnections? connections;

  /// Runs the person's key commands in a terminal, absent where this computer offers none.
  final KeyCommands? keys;

  /// Feeds the host admin's central token to the host, in a terminal: nothing here sees it. It ends when the terminal
  /// does.
  final Future<void> Function(String host)? onGiveToken;

  /// What this computer does there: its work, daemon and vault, where the person's list holds the machine.
  final Widget? work;

  /// Starts work on the machine, absent where this computer cannot.
  final Future<String?> Function(String host, String? project)? onStartWork;

  /// The host's name.
  final String host;

  /// Changes when the rail asks the page to read the machine again.
  final int refresh;

  /// Returns to the list.
  final VoidCallback onBack;

  @override
  State<OrganizationHostPage> createState() => _OrganizationHostPageState();
}

class _OrganizationHostPageState extends State<OrganizationHostPage> {
  bool _acting = false;
  String? _refusal;

  /// Why the last press of *Start work* did not start, in words.
  String? _startWhy;

  /// What the host last said of itself, asked only of a host admin who is connected to it.
  HostProgress? _progress;
  bool _askedProgress = false;
  int _progressReads = 0;
  DateTime? _answeredAt;

  @override
  void initState() {
    super.initState();
    if (widget.organization.view == null) unawaited(widget.organization.refresh());
    widget.connections?.addListener(_askProgress);
    widget.organization.addListener(_askProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askProgress();
    });
  }

  @override
  void dispose() {
    widget.connections?.removeListener(_askProgress);
    widget.organization.removeListener(_askProgress);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrganizationHostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      _askedProgress = false;
      _askProgress();
    }
  }

  bool get _isAdminHere {
    final view = widget.organization.view;
    final host = view?.hosts.where((host) => host.name == widget.host).firstOrNull;
    return view != null && host != null && view.holdsRoles && host.admins.contains(view.me);
  }

  void _askProgress() {
    final connections = widget.connections;
    if (connections == null || !connections.connected(widget.host) || !_isAdminHere) {
      _askedProgress = false;
      return;
    }
    if (_askedProgress) return;
    _askedProgress = true;
    unawaited(_read(() => connections.progress(widget.host)));
  }

  /// Takes what the host says; a refusal is shown on the page, never read as a state.
  Future<void> _read(Future<HostProgress> Function() ask) async {
    final read = ++_progressReads;
    setState(() {
      _acting = true;
      _refusal = null;
    });
    HostProgress? progress;
    String? refusal;
    try {
      progress = await ask();
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    // An earlier status answer must not replace the result of a later fetch.
    if (!mounted || read != _progressReads) return;
    setState(() {
      if (progress != null) {
        _progress = progress;
        _answeredAt = DateTime.now();
      }
      _acting = false;
      _refusal = refusal;
    });
  }

  Future<void> _giveToken() async {
    final first = _progress?.waitsForToken ?? false;
    await widget.onGiveToken?.call(widget.host);
    final connections = widget.connections;
    if (!mounted || connections == null) return;
    await _read(() => connections.progress(widget.host));
    // The host has made the account it could not make before: now the connection itself can come up.
    if (mounted && first && !(_progress?.waitsForToken ?? true)) await _act(() => connections.connect(widget.host));
  }

  void _show(Widget dialog) => unawaited(showDialog<void>(context: context, builder: (_) => dialog));

  Future<void> _makeBackupKey(OrganizationView view) async {
    await widget.keys!.makeBackup(context, scope: BackupScope.host(widget.host), base: view.revision);
    await widget.organization.refresh();
  }

  /// Runs one thing of the connection's, its refusal shown on the page; nothing is shown as done before its answer.
  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _acting = true;
      _refusal = null;
    });
    String? refusal;
    try {
      await action();
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    if (!mounted) return;
    setState(() {
      _acting = false;
      _refusal = refusal;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.organization, ?widget.connections]),
    builder: (context, _) {
      final view = widget.organization.view;
      final host = view?.hosts.where((host) => host.name == widget.host).firstOrNull;
      final isAdmin = view != null && host != null && view.holdsRoles && host.admins.contains(view.me);
      return ListView(
        key: ValueKey('organization-host ${widget.host}'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          OrganizationChangeMark(widget.organization),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('organization-host-back'),
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Machines'),
            ),
          ),
          Text(widget.host, style: Theme.of(context).textTheme.headlineSmall),
          if (widget.organization.problem case final problem?) _Problem(problem),
          if (_refusal case final refusal?) _Problem(refusal),
          if (view != null && host == null) Text('${view.name} has no machine ${widget.host}.'),
          if (view != null && host != null) ...[
            _connection(view, host),
            ?widget.work,
            if (isAdmin) ...[
              const SizedBox(height: Space.normal),
              Text('Managing this machine', style: Theme.of(context).textTheme.titleMedium),
            ],
            _reachRow(view, host, isAdmin),
            if (isAdmin) ..._howItStands(view, host),
            if (!isAdmin)
              const Text(
                "The project list is the organization's word; only a connected Machine Admin can read "
                'what the machine still carries.',
              ),
            const SizedBox(height: Space.normal),
            _projects(view, host, isAdmin),
            _admins(view, host, isAdmin),
          ],
        ],
      );
    },
  );

  /// What only a host admin can read: whether the host waits for their token, and who is locked out and until when.
  List<Widget> _howItStands(OrganizationView view, OrganizationHost host) {
    final connected = widget.connections?.connected(host.name) ?? false;
    final progress = _progress;
    if (!connected) {
      return const [
        Text("Connect to this machine to read how far it has come; the list here is the organization's word."),
      ];
    }
    return [
      if (_acting) const Text('Waiting for the machine…'),
      if (_answeredAt case final answered?)
        Text('Machine last answered at ${TimeOfDay.fromDateTime(answered.toLocal()).format(context)}'),
      if (progress != null && progress.wantsToken) ...[
        if (progress.waitsForToken) Text(organizationTokenWords(view, host.name)),
        for (final project in progress.projects)
          if (project.waitsForToken) Text(organizationTokenWords(view, host.name, project: project.project)),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey('organization.giveToken'),
            onPressed: _acting || widget.onGiveToken == null ? null : () => unawaited(_giveToken()),
            child: Text('Give it my ${organizationForgeName(view)} token…'),
          ),
        ),
      ],
      if (progress?.refused case final refused?)
        Text(
          key: const ValueKey('organization.refused'),
          'The machine refused its last fetch and stays on what it took before: $refused. '
          'That can be a removal or a commit nobody allowed: look at which, it does not say.',
        ),
      for (final person in progress?.locked ?? const <HostLockedPerson>[])
        Text(
          key: ValueKey('organization.locked/${person.login}'),
          '${person.login}: locked, account deleted on ${person.purgeOn}',
        ),
    ];
  }

  Widget _reachRow(OrganizationView view, OrganizationHost host, bool isAdmin) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: Space.normal,
    runSpacing: Space.small,
    children: [
      Text('Organization ${view.name} · ${_reach(host)} · SSH host key ${host.hostKey ?? 'not entered yet'}'),
      if (isAdmin) ...[
        OutlinedButton(
          key: const ValueKey('organization.changeHost'),
          onPressed: () => _show(_ChangeHostDialog(widget.organization, host)),
          child: const Text('Change address and key…'),
        ),
        Tooltip(
          message: 'Fetch and apply the organization on this machine now, rather than at its next follow.',
          child: OutlinedButton(
            key: const ValueKey('organization.refreshHost'),
            onPressed: _acting || !(widget.connections?.connected(host.name) ?? false)
                ? null
                : () => unawaited(_read(() => widget.connections!.refresh(host.name))),
            child: const Text('Fetch now'),
          ),
        ),
      ],
    ],
  );

  Widget _projects(OrganizationView view, OrganizationHost host, bool isAdmin) {
    final readsMachine = isAdmin && (widget.connections?.connected(host.name) ?? false);
    final names = {
      ...host.projects,
      if (readsMachine)
        for (final project in _progress?.projects ?? const <HostProjectProgress>[]) project.project,
    };
    return FilteredListSection(
      title: 'Projects on this machine',
      storageId: 'host-projects ${host.name}',
      rows: [
        for (final name in names)
          (
            words: name,
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(name),
              subtitle: Text(
                [
                  _projectWords(view, name),
                  if (readsMachine) ...[
                    if (!host.projects.contains(name)) 'being taken off, which can take up to five minutes',
                    ?_progressWords(view, host, name),
                  ],
                ].join(' · '),
              ),
            ),
          ),
      ],
    );
  }

  /// The host's own word on [name], which only a host admin reads: the organization's word is carried or not.
  String? _progressWords(OrganizationView view, OrganizationHost host, String name) {
    final progress = _progress?.of(name);
    if (progress == null) return null;
    if (progress.hasNoAddress) {
      return "the machine has no address for it: a token cannot help until the project's admin opens it or files its "
          'address anew, and it then needs your token once more';
    }
    return switch (progress.state) {
      'carried' => switch (progress.why) {
        final why? => 'on the machine: $why',
        null => 'on the machine',
      },
      // The host says this of a project going either way; one leaving is already said on its row.
      'pending' when !host.projects.contains(name) => progress.why,
      'pending' => switch (progress.why) {
        final why? => 'not on the machine yet: $why',
        null => 'being put on, which can take up to five minutes',
      },
      'waiting-for-token' => switch (progress.why) {
        final why? => 'waits for your ${organizationForgeName(view)} token: $why',
        null => 'waits for your ${organizationForgeName(view)} token',
      },
      'held' => 'held: ${progress.why ?? 'it has unpushed work'}',
      'refused' => switch (progress.why) {
        final why? => 'refused by the machine: $why',
        null => 'refused by the machine',
      },
      final word => word,
    };
  }

  String _projectWords(OrganizationView view, String name) {
    final project = view.projects.where((project) => project.name == name).firstOrNull;
    if (project == null) return 'not in the organization';
    return peopleOf(project);
  }

  Widget _admins(OrganizationView view, OrganizationHost host, bool isAdmin) {
    final candidates = [
      for (final person in view.holdingRoles)
        if (!host.admins.contains(person.login)) person.login,
    ];
    return FilteredListSection(
      title: 'Machine Admins',
      storageId: 'host-admins ${host.name}',
      actions: [
        if (view.mayNameAdminsOf(host))
          OutlinedButton.icon(
            key: const ValueKey('organization.addHostAdmin'),
            onPressed: candidates.isEmpty
                ? null
                : () => _show(
                    OrganizationPersonDialog(
                      widget.organization,
                      people: candidates,
                      title: 'Another Machine Admin of ${host.name}',
                      personLabel: 'Machine Admin',
                      words: 'They may put projects on it, take them off, and name its Machine Admins, as you may.',
                      confirm: 'Name them',
                      change: OrganizationChange.addHostAdmin,
                      input: (_, person) => {'host': host.name, 'login': person},
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add a Machine Admin'),
          ),
        if (isAdmin && widget.keys != null)
          OutlinedButton(
            key: const ValueKey('organization.makeBackupKey'),
            onPressed: () => unawaited(_makeBackupKey(view)),
            child: const Text('Make a backup key…'),
          ),
      ],
      rows: [
        for (final admin in host.admins)
          (
            words: admin,
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(admin == view.me ? '$admin (you)' : admin),
              subtitle: Text(
                [
                  _standing(view, admin),
                  if (host.adminKeys.any((key) => key.login == admin && key.backup)) 'has a backup key',
                ].join(' · '),
              ),
              // The last host admin cannot be removed, so nothing offers it.
              trailing: view.mayNameAdminsOf(host) && host.admins.length > 1
                  ? CommandMenu(
                      commands: [
                        organizationCommand(
                          id: 'removeHostAdmin/$admin',
                          label: 'Remove…',
                          danger: true,
                          run: () => _show(
                            OrganizationConfirmDialog(
                              widget.organization,
                              title: 'Remove $admin as a Machine Admin of ${host.name}?',
                              words: 'They no longer manage this machine.',
                              confirm: 'Remove',
                              change: OrganizationChange.removeHostAdmin,
                              input: {'host': host.name, 'login': admin},
                            ),
                          ),
                        ),
                      ],
                      tooltip: 'What can be done with $admin',
                    )
                  : null,
            ),
          ),
      ],
    ).withOrganizationChanges(widget.organization, names: host.admins);
  }

  String _standing(OrganizationView view, String login) {
    final person = view.persons.where((person) => person.login == login).firstOrNull;
    return switch (person?.standing) {
      null => 'no card',
      CardStanding.trusted => 'trusted',
      CardStanding.notYet => 'not yet vouched for',
      CardStanding.refused => 'refused',
      CardStanding.revoked => 'revoked',
    };
  }

  /// Where this person stands with the machine, first on the page as it concerns everyone.
  Widget _connection(OrganizationView view, OrganizationHost host) {
    final connections = widget.connections;
    final connected = connections?.connected(host.name) ?? false;
    final ready = connected && (connections?.up(host.name) ?? false) && !(_progress?.waitsForToken ?? false);
    final why = _whyNotConnect(host, connections);
    final mine = [
      for (final project in view.projects)
        if (project.host == host.name && (project.admins.contains(view.me) || project.members.contains(view.me)))
          project.name,
    ];
    final name = host.name;
    final buttons = [
      if (ready && widget.onStartWork != null)
        FilledButton(
          key: ValueKey('organization.startWork/$name'),
          onPressed: () => unawaited(_startWork(mine, name)),
          child: Text(switch (mine) {
            [] => 'Start work',
            [final one] => 'Start work in $one',
            _ => 'Start work…',
          }),
        ),
      if (connected)
        OutlinedButton(
          key: ValueKey('organization.disconnect/$name'),
          onPressed: _acting ? null : () => unawaited(_act(() => connections!.disconnect(name))),
          child: const Text('Disconnect'),
        )
      else if (view.myHosts.contains(host))
        FilledButton(
          key: ValueKey('organization.connect/$name'),
          onPressed: _acting || why != null ? null : () => unawaited(_act(() => connections!.connect(name))),
          child: const Text('Connect'),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('organization.connectionWords'),
            ready
                ? 'Connected as ${view.me}.${mine.isEmpty ? '' : ' Ready to work on: ${mine.join(', ')}.'}'
                : connected
                ? 'Connected. $name makes your account once it has read the organization, up to five minutes after '
                      'your project is on it, and only once its admin has given it the token.'
                : why ??
                      'This computer has no connection to $name yet. You need one to work there; it is set up once, '
                          'whatever number of projects the machine carries.',
          ),
          if (connected)
            Text(
              "Disconnect ends this computer's connection only. Your account, work and vault there stay, and Connect "
              'brings it back.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: Space.small),
            Wrap(spacing: Space.small, runSpacing: Space.small, children: buttons),
          ],
          if (_startWhy case final why?)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(why, key: const ValueKey('organization.startWhy')),
            ),
        ],
      ),
    );
  }

  /// Starts work from this page in what the person has here: the one project, or the one they choose among several.
  /// The way into `default` is taken only with no project here, or by its name.
  Future<void> _startWork(List<String> mine, String host) async {
    final start = widget.onStartWork;
    if (start == null) return;
    setState(() => _startWhy = null);
    final String? project;
    if (mine.length > 1) {
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('In which project?'),
          children: [
            for (final each in [...mine, defaultProject])
              SimpleDialogOption(
                key: ValueKey('organization.startWorkIn/$each'),
                onPressed: () => Navigator.of(context).pop(each),
                child: Text(each == defaultProject ? 'Default' : each),
              ),
          ],
        ),
      );
      if (chosen == null) return;
      project = chosen == defaultProject ? null : chosen;
    } else {
      project = mine.firstOrNull;
    }
    final why = await start(host, project);
    if (mounted) setState(() => _startWhy = why);
  }
}

/// Asks for a host's address, port and host key, which its host admin enters.
class _ChangeHostDialog extends StatefulWidget {
  const _ChangeHostDialog(this.organization, this.host);

  final Organization organization;
  final OrganizationHost host;

  @override
  State<_ChangeHostDialog> createState() => _ChangeHostDialogState();
}

class _ChangeHostDialogState extends State<_ChangeHostDialog> {
  late final _address = TextEditingController(text: widget.host.address);
  late final _port = TextEditingController(text: '${widget.host.port ?? 22}');
  late final _key = TextEditingController(text: widget.host.hostKey);
  late final _web = TextEditingController(text: widget.host.webPort?.toString() ?? '');
  late final _git = TextEditingController(text: widget.host.gitPort?.toString() ?? '');
  late final _matrix = TextEditingController(text: widget.host.matrixPort?.toString() ?? '');

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    _key.dispose();
    _web.dispose();
    _git.dispose();
    _matrix.dispose();
    super.dispose();
  }

  // Emptied, a service the card names comes off it; left empty, there is nothing to say of it.
  static String _portWord(TextEditingController field, int? onTheCard) =>
      field.text.trim().isEmpty && onTheCard != null ? 'none' : field.text.trim();

  String? _invalid() {
    if (!isUsableHostAddress(_address.text.trim())) {
      return 'Give a machine name or IP address that other computers reach this server at.';
    }
    for (final port in [_port, _web, _git, _matrix]) {
      // Only the ssh port must be there: a host may run no forge and no homeserver.
      if (port != _port && port.text.trim().isEmpty) continue;
      final number = int.tryParse(port.text.trim());
      if (number == null || number < 1 || number > 65535) return 'A port is a number from 1 to 65535.';
    }
    if (_web.text.trim().isEmpty != _git.text.trim().isEmpty) {
      return 'A forge has both a web port and a git port; leave both empty on a machine with no forge.';
    }
    try {
      checkedEd25519(_key.text.trim());
    } on FormatException {
      return 'The SSH key is one line starting with ssh-ed25519.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    title: 'Address and SSH key of ${widget.host.name}',
    confirm: 'Change them',
    body: (context, changed) => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.small,
      children: [
        const SizedBox.shrink(),
        TextField(
          key: const Key('organization-host-address'),
          controller: _address,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Machine name or IP address'),
          onChanged: (_) => changed(),
        ),
        TextField(
          key: const Key('organization-host-port'),
          controller: _port,
          decoration: const InputDecoration(labelText: 'SSH port'),
          onChanged: (_) => changed(),
        ),
        TextField(
          key: const Key('organization-host-key'),
          controller: _key,
          decoration: const InputDecoration(
            labelText: 'SSH key',
            helperText: "The server's /etc/ssh/ssh_host_ed25519_key.pub, one line.",
          ),
          onChanged: (_) => changed(),
        ),
        for (final (key, label, controller) in [
          ('organization-host-web-port', 'Forge web port, empty with no forge', _web),
          ('organization-host-git-port', 'Forge git port, empty with no forge', _git),
          ('organization-host-matrix-port', 'Matrix port, empty with no homeserver', _matrix),
        ])
          TextField(
            key: Key(key),
            controller: controller,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => changed(),
          ),
        const SizedBox(height: Space.small),
        const Text('Everyone connected to this machine is asked to trust the new key before reaching it again.'),
      ],
    ),
    invalid: _invalid,
    ask: () => [_address, _port, _key].any((field) => field.text.trim().isEmpty)
        ? null
        : (
            change: OrganizationChange.changeHost,
            input: {
              'host': widget.host.name,
              'address': _address.text.trim(),
              'port': _port.text.trim(),
              'hostKey': _key.text.trim(),
              'webPort': _portWord(_web, widget.host.webPort),
              'gitPort': _portWord(_git, widget.host.gitPort),
              'matrixPort': _portWord(_matrix, widget.host.matrixPort),
            },
          ),
  );
}
