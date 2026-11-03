import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show checkedEd25519, isUsableHostAddress;

import '../app/host_progress.dart';
import '../app/key_recovery.dart' show BackupScope;
import '../app/organization_source.dart';
import 'filtered_list_section.dart';
import 'key_recovery_dialog.dart';
import 'organization_dialogs.dart';
import 'tokens.dart';

String _reach(OrganizationHost host) {
  final address = host.address;
  if (address == null) return 'no address yet';
  if (host.port == null) return address;
  return address.contains(':') ? '[$address]:${host.port}' : '$address:${host.port}';
}

/// The hosts of the organization this person has to do with, each with its one connection: every project of theirs on a
/// connected host is ready to work on, with no step of its own.
class OrganizationHostsSection extends StatefulWidget {
  /// Lists [organization]'s hosts for the person reading.
  const OrganizationHostsSection({required this.organization, required this.onHost, this.connections, super.key});

  /// The organization.
  final Organization organization;

  /// This person's connections, absent where this computer has none to make.
  final HostConnections? connections;

  /// Opens a host's page.
  final void Function(String host) onHost;

  @override
  State<OrganizationHostsSection> createState() => _OrganizationHostsSectionState();
}

class _OrganizationHostsSectionState extends State<OrganizationHostsSection> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.organization.refresh());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.organization, ?widget.connections]),
    builder: (context, _) {
      final view = widget.organization.view;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.organization.problem case final problem?) _Problem(problem),
          if (view != null)
            FilteredListSection(
              title: 'Hosts',
              storageId: 'my-hosts',
              rows: [
                for (final host in view.myHosts)
                  (
                    words: '${host.name} ${host.projects.join(' ')}',
                    child: _HostRow(
                      view: view,
                      host: host,
                      connections: widget.connections,
                      onOpen: () => widget.onHost(host.name),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
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
    ? 'Its host admin has not entered its address yet.'
    : null;

class _HostRow extends StatefulWidget {
  const _HostRow({required this.view, required this.host, required this.connections, required this.onOpen});

  final OrganizationView view;
  final OrganizationHost host;
  final HostConnections? connections;
  final VoidCallback onOpen;

  @override
  State<_HostRow> createState() => _HostRowState();
}

class _HostRowState extends State<_HostRow> {
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
              if (host.admins.contains(view.me)) 'you administer it',
              if (mine.isNotEmpty) 'your projects: ${mine.join(', ')}',
              if (connected) mine.isEmpty ? 'connected' : 'connected, ready to work on' else why ?? 'not connected yet',
            ].join(' · '),
          ),
          trailing: connected
              ? null
              : FilledButton(
                  key: ValueKey('organization.connect/${host.name}'),
                  onPressed: why != null || _connecting ? null : () => unawaited(_connect()),
                  child: const Text('Connect'),
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
    required this.onBack,
    this.connections,
    this.onGiveToken,
    this.keys,
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

  /// The host's name.
  final String host;

  /// Returns to the list.
  final VoidCallback onBack;

  @override
  State<OrganizationHostPage> createState() => _OrganizationHostPageState();
}

class _OrganizationHostPageState extends State<OrganizationHostPage> {
  bool _acting = false;
  String? _refusal;

  /// What the host last said of itself, asked only of a host admin who is connected to it.
  HostProgress? _progress;
  bool _askedProgress = false;

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
  Future<void> _read(Future<HostProgress> Function() ask) => _act(() async {
    final progress = await ask();
    if (mounted) setState(() => _progress = progress);
  });

  Future<void> _giveToken() async {
    final first = _progress?.waitsForToken ?? false;
    await widget.onGiveToken?.call(widget.host);
    final connections = widget.connections;
    if (!mounted || connections == null) return;
    await _read(() => connections.progress(widget.host));
    // The host has made the account it could not make before: now the connection itself can come up.
    if (mounted && first && !(_progress?.waitsForToken ?? true)) await _act(() => connections.connect(widget.host));
  }

  /// Putting a project on needs the token at once: once it was taken, the host is asked to fetch, and says if it waits.
  Future<void> _putOn(Widget dialog, OrganizationHost before) async {
    await showDialog<void>(context: context, builder: (_) => dialog);
    final now = widget.organization.view?.hosts.where((host) => host.name == before.name).firstOrNull;
    final connections = widget.connections;
    if (!mounted || now == null || now.projects.length <= before.projects.length || connections == null) return;
    if (connections.connected(before.name)) await _read(() => connections.refresh(before.name));
  }

  void _show(Widget dialog) => unawaited(showDialog<void>(context: context, builder: (_) => dialog));

  Future<void> _makeBackupKey(OrganizationView view) async {
    await widget.keys!.makeBackup(context, scope: BackupScope.host(widget.host), base: view.revision);
    await widget.organization.refresh();
  }

  void _putOnDialog(OrganizationHost host, Widget dialog) => unawaited(_putOn(dialog, host));

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
          if (view != null && host == null) Text('${view.name} has no host ${widget.host}.'),
          if (view != null && host != null) ...[
            _reachRow(view, host, isAdmin),
            if (isAdmin) ..._howItStands(host),
            const SizedBox(height: Space.normal),
            _projects(view, host, isAdmin),
            _admins(view, host, isAdmin),
            _connection(view, host),
          ],
        ],
      );
    },
  );

  /// What only a host admin can read: whether the host waits for their token, and who is locked out and until when.
  List<Widget> _howItStands(OrganizationHost host) {
    final connected = widget.connections?.connected(host.name) ?? false;
    final progress = _progress;
    if (!connected) {
      return const [
        Text("Connect to this host to read how far it has come; the list here is the organization's word."),
      ];
    }
    return [
      if (progress?.wantsToken ?? false) ...[
        const Text('The host waits for your central token before it can go on.'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey('organization.giveToken'),
            onPressed: _acting || widget.onGiveToken == null ? null : () => unawaited(_giveToken()),
            child: const Text('Give it the token…'),
          ),
        ),
      ],
      if (progress?.refused case final refused?)
        Text(
          key: const ValueKey('organization.refused'),
          'The host refused its last fetch and stays on what it took before: $refused. '
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
      Text('Organization ${view.name} · ${_reach(host)} · host key ${host.hostKey ?? 'not entered yet'}'),
      if (isAdmin) ...[
        OutlinedButton(
          key: const ValueKey('organization.changeHost'),
          onPressed: () => _show(_ChangeHostDialog(widget.organization, host)),
          child: const Text('Change address and host key…'),
        ),
        OutlinedButton(
          key: const ValueKey('organization.refreshHost'),
          onPressed: _acting || widget.connections == null
              ? null
              : () => unawaited(_read(() => widget.connections!.refresh(host.name))),
          child: const Text('Refresh'),
        ),
      ],
    ],
  );

  Widget _projects(OrganizationView view, OrganizationHost host, bool isAdmin) {
    final offered = [for (final project in view.projectsOnNoHost) project.name];
    return FilteredListSection(
      title: 'Projects on this host',
      storageId: 'host-projects ${host.name}',
      actions: [
        if (isAdmin)
          OutlinedButton.icon(
            key: const ValueKey('organization.addProjectToHost'),
            onPressed: offered.isEmpty
                ? null
                : () => _putOnDialog(
                    host,
                    OrganizationPersonDialog(
                      widget.organization,
                      people: offered,
                      helper: 'A project is on one host at a time: these are on none yet.',
                      title: 'Put a project on ${host.name}',
                      personLabel: 'Project',
                      words:
                          'Every member comes with the project. Connect to this host, and if it waits for your central '
                          'token this page offers to give it, once, in a terminal, for its deploy keys. The host does '
                          'the rest by itself, which can take up to five minutes.',
                      confirm: 'Put it on the host',
                      change: OrganizationChange.addProjectToHost,
                      input: (_, project) => {'host': host.name, 'project': project},
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Put a project on the host'),
          ),
      ],
      rows: [
        for (final name in host.projects)
          (
            words: name,
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(name),
              subtitle: Text([_projectWords(view, name), if (isAdmin) ?_progressWords(name)].join(' · ')),
              trailing: isAdmin
                  ? TextButton(
                      key: ValueKey('organization.removeProjectFromHost/$name'),
                      onPressed: () => _show(
                        OrganizationConfirmDialog(
                          widget.organization,
                          title: 'Take $name off ${host.name}?',
                          words:
                              'Its members can no longer work on it here, once it holds no unpushed work. Its room on '
                              'this host goes then, with its conversation, where the host runs its own. The project '
                              'itself stays in the organization. This can take up to five minutes.',
                          confirm: 'Take it off',
                          change: OrganizationChange.removeProjectFromHost,
                          input: {'host': host.name, 'project': name},
                        ),
                      ),
                      child: const Text('Take off the host'),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// The host's own word on [name], which only a host admin reads: the organization's word is carried or not.
  String? _progressWords(String name) {
    final progress = _progress?.of(name);
    if (progress == null) return null;
    return switch (progress.state) {
      'carried' => 'on the host',
      'putting-on' => 'being put on, which can take up to five minutes',
      'waiting-for-token' => switch (progress.why) {
        final why? => 'waits for your central token: $why',
        null => 'waits for your central token',
      },
      'held' => 'held: ${progress.why ?? 'it has unpushed work'}',
      'gone' => 'taken off',
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
      title: 'Host admins',
      storageId: 'host-admins ${host.name}',
      actions: [
        if (isAdmin)
          OutlinedButton.icon(
            key: const ValueKey('organization.addHostAdmin'),
            onPressed: candidates.isEmpty
                ? null
                : () => _show(
                    OrganizationPersonDialog(
                      widget.organization,
                      people: candidates,
                      title: 'Another host admin of ${host.name}',
                      personLabel: 'Host admin',
                      words: 'They may put projects on it, take them off, and name its host admins, as you may.',
                      confirm: 'Name them',
                      change: OrganizationChange.addHostAdmin,
                      input: (_, person) => {'host': host.name, 'login': person},
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add a host admin'),
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
              trailing: isAdmin && host.admins.length > 1
                  ? TextButton(
                      key: ValueKey('organization.removeHostAdmin/$admin'),
                      onPressed: () => _show(
                        OrganizationConfirmDialog(
                          widget.organization,
                          title: 'Remove $admin as a host admin of ${host.name}?',
                          words: 'They no longer manage this host.',
                          confirm: 'Remove',
                          change: OrganizationChange.removeHostAdmin,
                          input: {'host': host.name, 'login': admin},
                        ),
                      ),
                      child: const Text('Remove'),
                    )
                  : null,
            ),
          ),
      ],
    );
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

  Widget _connection(OrganizationView view, OrganizationHost host) {
    final connections = widget.connections;
    final connected = connections?.connected(host.name) ?? false;
    final why = _whyNotConnect(host, connections);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your connection', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.small),
        Text(
          connected && (_progress?.waitsForToken ?? false)
              ? 'Not connected yet. The host makes your account once it has your token.'
              : connected
              ? 'Connected as ${view.me}, with the host key from the organization.'
              : why ?? 'Not connected yet. Connecting sets up one connection here, whatever number of projects it carries.',
        ),
        const SizedBox(height: Space.small),
        if (connected)
          OutlinedButton(
            key: ValueKey('organization.disconnect/${host.name}'),
            onPressed: _acting ? null : () => unawaited(_act(() => connections!.disconnect(host.name))),
            child: const Text('Disconnect'),
          )
        else if (view.myHosts.contains(host))
          FilledButton(
            key: ValueKey('organization.connect/${host.name}'),
            onPressed: _acting || why != null ? null : () => unawaited(_act(() => connections!.connect(host.name))),
            child: const Text('Connect'),
          ),
      ],
    );
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
      return 'Give a host name or IP address that other computers reach this server at.';
    }
    for (final port in [_port, _web, _git, _matrix]) {
      // Only the ssh port must be there: a host may run no forge and no homeserver.
      if (port != _port && port.text.trim().isEmpty) continue;
      final number = int.tryParse(port.text.trim());
      if (number == null || number < 1 || number > 65535) return 'A port is a number from 1 to 65535.';
    }
    if (_web.text.trim().isEmpty != _git.text.trim().isEmpty) {
      return 'A forge has both a web port and a git port; leave both empty on a host with no forge.';
    }
    try {
      checkedEd25519(_key.text.trim());
    } on FormatException {
      return 'The host key is one line starting with ssh-ed25519.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => OrganizationChangeDialog(
    organization: widget.organization,
    title: 'Address and host key of ${widget.host.name}',
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
          decoration: const InputDecoration(labelText: 'Host name or IP address'),
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
            labelText: 'Host key',
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
        const Text('Everyone connected to this host is asked to trust the new key before reaching it again.'),
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
