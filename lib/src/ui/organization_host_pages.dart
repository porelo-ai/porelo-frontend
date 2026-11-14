import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart' show defaultProject;
import 'package:porelo_host/porelo_host.dart' show checkedEd25519, isUsableHostAddress;

import '../app/commands.dart';
import '../app/host_progress.dart';
import '../app/host_runs.dart' show HostPreparation;
import '../app/key_recovery.dart' show BackupScope;
import '../app/organization_source.dart';
import '../app/tunnel.dart' show Tunnel;
import 'asking_button.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'key_recovery_dialog.dart';
import 'machines_page.dart' show HostPreparationMark, hostPreparationWords;
import 'organization_dialogs.dart';
import 'organization_token_words.dart';
import 'placing_project_dialog.dart' show GiveHostToken;
import 'tokens.dart';
import 'page_explanation.dart';
import 'expandable_list_row.dart';

/// What a preparation running for a machine says on the organization's row: its state, since when, and where.
String _preparingWords(HostPreparation run) {
  final started = run.record.startedAt?.toLocal();
  final since = started == null
      ? ''
      : ' since ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
  final address = run.record.givenAddress;
  final problem = run.problem ?? run.session.fix;
  return [
    '${hostPreparationWords(run)}$since${address.isEmpty ? '' : ' on $address'}',
    if (problem != null && problem.isNotEmpty) problem,
  ].join(' · ');
}

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
    this.onPrepare,
    this.preparation,
    this.onProtocol,
    this.onGiveToken,
    super.key,
  });

  /// Opens the token's page for this machine; its page where null.
  final VoidCallback? onGiveToken;

  /// *Set up this machine…*, absent where this computer offers none.
  final VoidCallback? onPrepare;

  /// The preparation running for it on this computer, null where none runs: the row says so, and offers its
  /// protocol rather than a second start.
  final HostPreparation? preparation;

  /// Opens [preparation]'s protocol.
  final void Function(HostPreparation run)? onProtocol;

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
    final waiting = !connected && (widget.connections?.waitsForToken(host.name) ?? false);
    // Prepared moments ago, it makes the person's account on its first follow: a turn-away until then is no refusal.
    final admitting = !connected && !waiting && (widget.connections?.waitsForAdmission(host.name) ?? false);
    final givesIt = host.admins.contains(view.me);
    // The right to connect is an account there, and that is what the person's own list of machines says.
    final hasAccount = view.myHosts.any((each) => each.name == host.name);
    final mine = [
      for (final project in view.projects)
        // A project carried in part may be on this machine and another, and the store names one host for it.
        if ((project.host == host.name || host.projects.contains(project.name)) &&
            !view.saysNoRepository(project) &&
            (project.admins.contains(view.me) || project.members.contains(view.me)))
          project.name,
    ];
    // What the machine said last of each: one it waits for the token for is never ready to work on.
    final forge = organizationForgeName(view);
    final waits = {
      for (final project in mine) project: ?waitingWords(widget.connections?.heard(host.name)?.of(project), forge),
    };
    // One the machine has taken some of is ready to work on there, while it waits for the rest.
    final ready = [
      for (final project in mine)
        if (!waits.containsKey(project) ||
            (widget.connections?.heard(host.name)?.of(project)?.taken.isNotEmpty ?? false))
          project,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LeafListRow(
          key: ValueKey('my-host ${host.name}'),
          chipFirst: true,
          state: widget.preparation != null
              ? hostPreparationWords(widget.preparation!)
              : connected
              ? 'Connected'
              : _connecting
              ? 'Connecting'
              : waiting
              ? 'Needs you'
              : admitting
              ? 'Waiting'
              : host.address == null
              ? 'not set up'
              : 'not connected yet',
          leading: switch (widget.preparation) {
            final run? => HostPreparationMark(run),
            null => const Icon(Icons.dns_outlined),
          },
          title: host.name,
          subtitle: Text(
            [
              if (widget.preparation case final run?) _preparingWords(run) else ?widget.words,
              if (host.admins.contains(view.me)) 'you administer it',
              if (mine.isNotEmpty) 'your projects: ${mine.join(', ')}',
              if (widget.preparation != null)
                ...const <String>[]
              else if (waiting)
                'waits for a first token'
              else if (admitting)
                Tunnel.admissionWords
              else if (connected)
                ready.isEmpty ? 'connected' : 'connected, ready to work on ${ready.join(', ')}'
              else if (host.address == null)
                '${host.name} is listed, not set up yet.${givesIt ? '' : ' It waits for ${host.admins.join(' or ')}.'}'
              else
                ?why,
              for (final MapEntry(key: project, value: words) in waits.entries) '$project $words',
            ].join(' · '),
          ),
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.small,
            children: [
              // While it is prepared, never a second start: its protocol, where this computer can open it.
              if (widget.preparation case final run?) ...[
                if (widget.onProtocol case final open?)
                  FilledButton(
                    key: ValueKey('organization.protocol/${host.name}'),
                    onPressed: () => open(run),
                    child: const Text('Open the protocol'),
                  ),
              ] else if (host.address == null && givesIt && widget.onPrepare != null && view.holdsRoles)
                FilledButton(
                  key: ValueKey('organization.prepare/${host.name}'),
                  onPressed: widget.onPrepare,
                  child: const Text('Set up this machine…'),
                ),
              if (waiting && givesIt)
                FilledButton(
                  key: ValueKey('organization.toToken/${host.name}'),
                  onPressed: widget.onGiveToken ?? widget.onOpen,
                  child: const Text('Give it your token…'),
                ),
              // Only the Machine Admin has another way on: anyone else connects again once it is given.
              if (hasAccount && !connected && !(waiting && givesIt))
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
        if (waiting)
          _Problem(
            givesIt
                ? organizationTokenWords(view, host.name)
                : '${host.name} waits for its Machine Admin (${host.admins.join(', ')}) to give it a first token. '
                      'Connect again after that.',
          ),
        if (_refusal case final refusal?) _Problem(refusal),
        if (!connected && !_connecting)
          if (widget.connections case final connections?)
            Align(alignment: Alignment.centerLeft, child: LastConnectAttempt(connections, host.name)),
      ],
    );
  }
}

/// *Show the last attempt*, where a *Connect* to [host] in this run has ended; nothing otherwise.
class LastConnectAttempt extends StatelessWidget {
  /// Reads the attempt from [connections].
  const LastConnectAttempt(this.connections, this.host, {super.key});

  /// Who kept it.
  final HostConnections connections;

  /// The machine.
  final String host;

  @override
  Widget build(BuildContext context) {
    final attempt = connections.lastAttempt(host);
    if (attempt == null) return const SizedBox.shrink();
    return TextButton(
      key: ValueKey('organization.attempt/$host'),
      onPressed: () => unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('The last Connect to $host'),
            content: SingleChildScrollView(
              child: SelectableText(
                key: const Key('organization-attempt-lines'),
                ['Began ${TimeOfDay.fromDateTime(attempt.at).format(context)}.', ...attempt.lines].join('\n'),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
          ),
        ),
      ),
      child: const Text('Show the last attempt'),
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
    this.path = const [],
    this.connections,
    this.onGiveToken,
    this.onStartWork,
    this.keys,
    this.work,
    this.machineProjects,
    this.onPrepare,
    this.preparing,
    this.onProtocol,
    this.onlyAdmins = false,
    this.version,
    this.lastAnswered,
    super.key,
  });

  /// Whether the page is the machine's *Machine Admins* leaf: their list and its two actions, nothing of the machine's
  /// own page again.
  final bool onlyAdmins;

  /// The Porelo version the machine's daemon last said, null where it has not answered.
  final String? version;

  /// When the machine's daemon last answered this window, null where it has not.
  final DateTime? lastAnswered;

  /// *Set up this machine…*, absent where this computer offers none.
  final void Function(String host)? onPrepare;

  /// The preparation running for a machine on this computer; null where none runs.
  final HostPreparation? Function(String host)? preparing;

  /// Opens a running preparation's protocol.
  final void Function(HostPreparation run)? onProtocol;

  /// The organization.
  final Organization organization;

  /// This person's connections, absent where this computer has none to make.
  final HostConnections? connections;

  /// Runs the person's key commands in a terminal, absent where this computer offers none.
  final KeyCommands? keys;

  /// Gives the host admin's central token to the host; answers the words to show beside the button, if any.
  final GiveHostToken? onGiveToken;

  /// What this computer does there: its work, daemon and vault, where the person's list holds the machine.
  final Widget? work;

  /// The projects the machine itself last listed, each with its row, where the person's list holds the machine:
  /// they join the organization's in the page's one list of projects.
  final List<({String name, Widget row})>? machineProjects;

  /// Starts work on the machine, absent where this computer cannot.
  final Future<String?> Function(String host, String? project)? onStartWork;

  /// The host's name.
  final String host;

  /// Changes when the rail asks the page to read the machine again.
  final int refresh;

  /// The full ancestry when opened from the organization tree.
  final List<LeafPathStep> path;

  /// Returns to the list.
  final VoidCallback onBack;

  @override
  State<OrganizationHostPage> createState() => _OrganizationHostPageState();
}

class _OrganizationHostPageState extends State<OrganizationHostPage> {
  /// How many asks of the machine run now: the page is busy while any does, and one ending does not free it while
  /// another still runs.
  int _working = 0;
  bool get _acting => _working > 0;
  String? _refusal;

  /// What the host last said of itself, asked only of a host admin who is connected to it.
  HostProgress? _progress;
  bool _askedProgress = false;
  int _progressReads = 0;

  /// What the machine said last, wherever it was asked, as this page last took it.
  HostProgress? _heardSeen;
  DateTime? _answeredAt;

  /// Whether the machine's forge last answered through this computer's forward; null where it was not asked.
  bool? _forgeAnswers;

  /// Whether the forward was raised anew and the forge still gave no answer: its cause is then on the host.
  bool _raisedInVain = false;
  bool _askedForge = false;
  int _forgeReads = 0;

  @override
  void initState() {
    super.initState();
    if (widget.organization.view == null) unawaited(widget.organization.refresh());
    widget.connections?.addListener(_askProgress);
    widget.organization.addListener(_askProgress);
    widget.connections?.addListener(_askForge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _askProgress();
        _askForge();
      }
    });
  }

  @override
  void dispose() {
    widget.connections?.removeListener(_askProgress);
    widget.organization.removeListener(_askProgress);
    widget.connections?.removeListener(_askForge);
    super.dispose();
  }

  /// Asks once per connection that is up whether the machine's forge answers through the forward; a connection that
  /// goes down forgets the answer, as it no longer says anything of the forward.
  void _askForge() {
    final connections = widget.connections;
    if (widget.onlyAdmins || connections == null || !connections.up(widget.host)) {
      _askedForge = false;
      if (_forgeAnswers != null && mounted) setState(() => _forgeAnswers = null);
      return;
    }
    if (_askedForge) return;
    _askedForge = true;
    unawaited(_readForge());
  }

  Future<void> _readForge() async {
    final read = ++_forgeReads;
    final answers = await widget.connections?.forgeAnswers(widget.host);
    if (!mounted || read != _forgeReads) return;
    setState(() {
      _forgeAnswers = answers;
      if (answers != false) _raisedInVain = false;
    });
  }

  /// Opens the forge, its forward raised anew first where it gave no answer, then asks the forge again.
  Future<String?> _openForge() async {
    final wasDead = _forgeAnswers == false;
    final refused = await openHostForge(host: widget.host, connections: widget.connections);
    if (!mounted) return refused;
    await _readForge();
    if (mounted && wasDead && refused == null) setState(() => _raisedInVain = _forgeAnswers == false);
    return refused;
  }

  @override
  void didUpdateWidget(covariant OrganizationHostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      // The refresh asks every machine its Machine Admin may ask again, once: its answer is taken as it comes, and
      // only a machine nothing was heard of yet is asked from here.
      _askedProgress = false;
      _askProgress();
      _askedForge = false;
      _askForge();
    }
  }

  bool get _isAdminHere {
    final view = widget.organization.view;
    final host = view?.hosts.where((host) => host.name == widget.host).firstOrNull;
    return view != null && host != null && view.holdsRoles && host.admins.contains(view.me);
  }

  /// Asks the machine how far it has come, once per connection: what it said already, wherever it was asked, is taken
  /// rather than asked again as root. What it says later from anywhere, as after its token was given or a refresh, is
  /// taken too.
  void _askProgress() {
    final connections = widget.connections;
    if (connections == null || !connections.connected(widget.host) || !_isAdminHere) {
      _askedProgress = false;
      // Losing contact keeps the last word read; one no longer theirs to read is no word of theirs now.
      if (!_isAdminHere && _progress != null) {
        setState(() {
          _progress = null;
          _heardSeen = null;
        });
      }
      return;
    }
    final heard = connections.heard(widget.host);
    if (_askedProgress || heard != null) {
      _askedProgress = true;
      // Its own read in flight answers for itself, and the newest of it stands.
      if (heard != null && !identical(heard, _heardSeen) && !_acting) {
        _heardSeen = heard;
        if (!identical(heard, _progress)) setState(() => _progress = heard);
      }
      return;
    }
    _askedProgress = true;
    unawaited(_read(() => connections.ask(widget.host)));
  }

  /// Takes what the host says; a refusal is shown on the page, never read as a state. Asked by a button, the refusal
  /// is answered to it, to stand beside it, and the page's head keeps none.
  Future<String?> _read(Future<HostProgress> Function() ask, {bool byAButton = false}) async {
    final read = ++_progressReads;
    setState(() {
      _working++;
      _refusal = null;
    });
    HostProgress? progress;
    String? refusal;
    try {
      progress = await ask();
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    if (!mounted) return refusal;
    // An earlier status answer must not replace the result of a later fetch.
    final latest = read == _progressReads;
    setState(() {
      _working--;
      if (latest && progress != null) {
        _progress = progress;
        _answeredAt = DateTime.now();
      }
      if (latest && !byAButton) _refusal = refusal;
    });
    return refusal;
  }

  /// Gives the host the token, then reads it again; answers why it was not given, or why the reading failed.
  Future<String?> _giveToken() async {
    final first = (_progress?.waitsForToken ?? false) || _waitHeardElsewhere(widget.host);
    final before = widget.connections?.heard(widget.host);
    // The page is busy while the token is given, as for any other ask of the machine.
    setState(() => _working++);
    final String? words;
    try {
      words = await widget.onGiveToken?.call(widget.host);
    } finally {
      if (mounted) setState(() => _working--);
    }
    final connections = widget.connections;
    if (!mounted || connections == null) return words;
    // A given token has the machine asked once already, where it was given: its answer is taken, not asked again.
    final heard = connections.heard(widget.host);
    final refusal = heard != null && !identical(heard, before)
        ? await _read(() async => heard, byAButton: true)
        : await _read(() => connections.ask(widget.host), byAButton: true);
    // The host has made the account it could not make before: now the connection itself can come up.
    final answer = mounted && first && !(_progress?.waitsForToken ?? true)
        ? words ?? await _act(() => connections.connect(widget.host), byAButton: true)
        : words ?? refusal;
    // The button goes once the machine wants no token: its answer then stands at the page's head, not nowhere.
    if (mounted && answer != null && !(_progress?.wantsToken ?? false)) setState(() => _refusal = answer);
    return answer;
  }

  void _show(Widget dialog) => unawaited(showDialog<void>(context: context, builder: (_) => dialog));

  Future<void> _makeBackupKey(OrganizationView view) async {
    await widget.keys!.makeBackup(context, scope: BackupScope.host(widget.host), base: view.revision);
    await widget.organization.refresh();
  }

  /// Runs one thing of the connection's, its refusal shown on the page, or answered to the button that asked;
  /// nothing is shown as done before its answer.
  Future<String?> _act(Future<void> Function() action, {bool byAButton = false}) async {
    setState(() {
      _working++;
      _refusal = null;
    });
    String? refusal;
    try {
      await action();
    } on OrganizationRefused catch (refused) {
      refusal = refused.words;
    }
    if (!mounted) return refusal;
    setState(() {
      _working--;
      if (!byAButton) _refusal = refusal;
    });
    return refusal;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.organization, ?widget.connections]),
    builder: (context, _) {
      final view = widget.organization.view;
      final host = view?.hosts.where((host) => host.name == widget.host).firstOrNull;
      final isAdmin = view != null && host != null && view.holdsRoles && host.admins.contains(view.me);
      final path = widget.path.isEmpty ? <LeafPathStep>[(label: 'My machines', go: widget.onBack)] : widget.path;
      final problems = [
        if (widget.organization.problem case final problem?) _Problem(problem),
        if (_refusal case final refusal?) _Problem(refusal),
        if (view != null && host == null) Text('${view.name} has no machine ${widget.host}.'),
      ];
      if (widget.onlyAdmins) {
        return ListView(
          key: ValueKey('organization-host-admins ${widget.host}'),
          padding: const EdgeInsets.all(Space.normal),
          children: [
            OrganizationChangeMark(widget.organization),
            if (view == null || host == null) ...[
              PageHead(title: 'Machine Admins', titleInAppBar: false, path: path, subtitle: 'not read'),
              ...problems,
            ] else
              _admins(view, host, isAdmin, path: path, beforeRows: problems),
          ],
        );
      }
      return ListView(
        key: ValueKey('organization-host ${widget.host}'),
        padding: const EdgeInsets.all(Space.normal),
        children: [
          OrganizationChangeMark(widget.organization),
          PageHead(
            title: widget.host,
            titleInAppBar: false,
            path: path,
            pathKeys: const {'My machines': Key('organization-host-back'), 'Machines': Key('organization-host-back')},
            titleChip: _stateChip(host),
            subtitle: _headWords(),
          ),
          ...problems,
          if (view != null && host != null) ...[
            _connection(view, host),
            if (isAdmin) ..._howItStands(view, host),
            // Said to whoever reads the page here, Machine Admin or not: it is this computer's own run.
            if (widget.preparing?.call(host.name) case final run?)
              Text('This computer prepares it: ${_preparingWords(run)}', key: const ValueKey('organization.preparing')),
            ?widget.work,
            // One list of the machine's projects, then its managing as a section of its own, never between two lists.
            const SizedBox(height: Space.normal),
            _projects(view, host, isAdmin),
            if (!isAdmin)
              const Text(
                "Where a project comes from the organization, that is the organization's word; only a connected "
                'Machine Admin can read what the machine still carries.',
              ),
            const SizedBox(height: Space.normal),
            if (isAdmin) Text('Managing this machine', style: Theme.of(context).textTheme.titleMedium),
            _reachRow(view, host, isAdmin),
            _admins(view, host, isAdmin),
          ],
        ],
      );
    },
  );

  /// The machine's state beside its name, said of this computer's connection to it.
  Widget _stateChip(OrganizationHost? host) {
    final connections = widget.connections;
    if (host == null || connections == null) return const StateChip('not read');
    final heard = _isAdminHere && _waitHeardElsewhere(host.name);
    if (!connections.connected(host.name) && !heard) return const StateChip('Not connected');
    if (heard || connections.waitsForToken(host.name) || (_progress?.waitsForToken ?? false)) {
      return const StateChip('Waiting for its token', toneWords: 'waiting');
    }
    if (!connections.up(host.name)) return const StateChip('Connection down', toneWords: 'not connected');
    return const StateChip('Connected');
  }

  /// Its Porelo and when it last answered, either of them said as not read where it is not known.
  String _headWords() {
    final answers = [?widget.lastAnswered, ?_answeredAt]..sort();
    final last = answers.lastOrNull;
    return 'Porelo ${widget.version ?? 'not read'} · last answered '
        '${last == null ? 'not read' : TimeOfDay.fromDateTime(last.toLocal()).format(context)}';
  }

  /// Whether the last word this window has of [host], wherever it was heard, is that it waits for its first token,
  /// while the page's own read says nothing of it: not connected, not read yet, or its read refused.
  bool _waitHeardElsewhere(String host) {
    final connections = widget.connections;
    final progress = _progress;
    if (connections == null || (progress?.waitsForToken ?? false)) return false;
    // The page's own read stands, unless the wait was heard after it.
    final at = connections.tokenWaitHeard(host);
    if (progress != null) return at != null && (_answeredAt == null || at.isAfter(_answeredAt!));
    return at != null || (connections.connected(host) && connections.waitsForToken(host));
  }

  /// When and where the wait [_waitHeardElsewhere] found was heard, and what giving the token does from here.
  String _waitHeardWords(String host, String forge) {
    final at = widget.connections?.tokenWaitHeard(host);
    final when = at == null ? '' : ' at ${TimeOfDay.fromDateTime(at.toLocal()).format(context)}';
    final connected = widget.connections?.connected(host) ?? false;
    return 'Last heard$when: $host waits for your $forge token. '
        '${connected ? 'This page has not read it since.' : 'This window is not connected to it now; giving the token connects first.'}';
  }

  /// What only a host admin can read: whether the host waits for their token, and who is locked out and until when.
  List<Widget> _howItStands(OrganizationView view, OrganizationHost host) {
    final connected = widget.connections?.connected(host.name) ?? false;
    final progress = _progress;
    final heardElsewhere = _waitHeardElsewhere(host.name);
    if (!connected && !heardElsewhere) {
      return const [
        Text("Connect to this machine to read how far it has come; the list here is the organization's word."),
      ];
    }
    return [
      if (_acting) const Text('Waiting for the machine…'),
      if (heardElsewhere || (progress != null && progress.wantsToken)) ...[
        if (heardElsewhere) ...[
          Text(organizationTokenWords(view, host.name)),
          Text(
            key: const ValueKey('organization.tokenWaitHeard'),
            _waitHeardWords(host.name, organizationForgeName(view)),
          ),
        ] else if (progress!.waitsForToken)
          Text(organizationTokenWords(view, host.name)),
        if (connected)
          for (final project in progress?.projects ?? const <HostProjectProgress>[])
            if (project.waitsForToken) Text(organizationTokenWords(view, host.name, project: project.project)),
        Align(
          alignment: Alignment.centerLeft,
          child: AskingButton(
            buttonKey: const ValueKey('organization.giveToken'),
            answerKey: const ValueKey('organization.tokenWhy'),
            filled: true,
            waiting: 'Giving ${host.name} your token, then asking how it stands…',
            onAsk: _acting || widget.onGiveToken == null ? null : _giveToken,
            label: Text('Give it my ${organizationForgeName(view)} token…'),
          ),
        ),
      ],
      if (connected) ...[
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
      ],
    ];
  }

  Widget _reachRow(OrganizationView view, OrganizationHost host, bool isAdmin) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: Space.normal,
    runSpacing: Space.small,
    children: [
      Text('Organization ${view.name} · ${_reach(host)} · SSH host key ${host.hostKey ?? 'not entered yet'}'),
      if (isAdmin) ...[
        if (widget.preparing?.call(host.name) case final run?) ...[
          if (widget.onProtocol case final open?)
            FilledButton(
              key: const ValueKey('organization.hostProtocol'),
              onPressed: () => open(run),
              child: const Text('Open the protocol'),
            ),
        ] else if (host.hasNoReach && widget.onPrepare != null)
          FilledButton(
            key: const ValueKey('organization.prepareHost'),
            onPressed: () => widget.onPrepare!(host.name),
            child: const Text('Set up this machine…'),
          ),
        OutlinedButton(
          key: const ValueKey('organization.changeHost'),
          onPressed: () => _show(HostAddressDialog(widget.organization, host)),
          child: Text(host.hasNoReach ? 'Enter address and key…' : 'Change address and key…'),
        ),
        Tooltip(
          message: 'Fetch and apply the organization on this machine now, rather than at its next follow.',
          child: AskingButton(
            buttonKey: const ValueKey('organization.refreshHost'),
            answerKey: const ValueKey('organization.refreshWhy'),
            waiting: '${host.name} fetches and applies the organization…',
            onAsk: _acting || !(widget.connections?.connected(host.name) ?? false)
                ? null
                : () async {
                    // Said of this fetch's own answer, not of whatever the page last read.
                    HostProgress? fetched;
                    final refusal = await _read(
                      () async => fetched = await widget.connections!.refresh(host.name),
                      byAButton: true,
                    );
                    return refusal ?? _fetchedWords(host.name, fetched);
                  },
            label: const Text('Fetch now'),
          ),
        ),
      ],
    ],
  );

  Widget _projects(OrganizationView view, OrganizationHost host, bool isAdmin) {
    final readsMachine = isAdmin && (widget.connections?.connected(host.name) ?? false);
    final organizations = {
      ...host.projects,
      if (readsMachine)
        for (final project in _progress?.projects ?? const <HostProjectProgress>[]) project.project,
    };
    final machines = {
      for (final row in widget.machineProjects ?? const <({String name, Widget row})>[]) row.name: row.row,
    };
    // The organization's word on a project, and the machine's own where its Machine Admin reads it.
    String organizationWords(String name) => [
      _projectWords(view, name),
      if (readsMachine) ...[
        if (!host.projects.contains(name)) 'being taken off, which can take up to five minutes',
        ?_progressWords(view, host, name),
      ],
    ].join(' · ');
    // A project put on this machine or taken off it, or one repository of it, asked from here or elsewhere: its
    // refusal stands here too, or the dialog that asked closed on nothing.
    final pending = [
      for (final change in widget.organization.rowChanges)
        if (change.input['host'] == host.name &&
            (change.change == OrganizationChange.addProjectToHost ||
                change.change == OrganizationChange.removeProjectFromHost))
          OrganizationPendingRow(widget.organization, change),
    ];
    final list = FilteredListSection(
      title: 'Projects',
      leaf: true,
      subtitle: counted({...machines.keys, ...organizations}.length, 'project', 'projects'),
      storageId: 'host-projects ${host.name}',
      emptyWords: 'No projects on this machine yet. A project goes on a machine once the machine is prepared.',
      rows: [
        for (final name in {...machines.keys, ...organizations})
          (
            words: name,
            child: machines[name] != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      machines[name]!,
                      Padding(
                        padding: const EdgeInsets.only(left: Space.normal, bottom: Space.small),
                        child: Text(
                          key: ValueKey('organization.projectSource/$name'),
                          organizations.contains(name)
                              ? 'Listed by the machine and by the organization: ${organizationWords(name)}'
                              : name == defaultProject
                              ? "Listed by the machine: every machine's own Default project"
                              : 'Listed by the machine; the organization does not name it here',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ..._carriedPart(host, name, isAdmin: isAdmin),
                      if (readsMachine) ..._repositoryProgress(host, name),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ItemListRow(
                        leading: const Icon(Icons.folder_outlined),
                        title: name,
                        subtitleMaxLines: null,
                        state: _progressChip(_progress?.of(name)),
                        onOpen: null,
                        menu: switch (_giveTokenFor(view, host, name)) {
                          final give? => CommandMenu(commands: [give], tooltip: 'What can be done with $name'),
                          null => null,
                        },
                        subtitleKey: ValueKey('organization.projectSource/$name'),
                        subtitle: 'From the organization: ${organizationWords(name)}',
                      ),
                      ..._carriedPart(host, name, isAdmin: isAdmin),
                      if (readsMachine) ..._repositoryProgress(host, name),
                    ],
                  ),
          ),
      ],
    );
    return pending.isEmpty
        ? list
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...pending, list]);
  }

  /// The host's word on a project for its chip: never its raw word where this build knows what it means, and never
  /// waiting for a token where the host has no address for it, which a token cannot help.
  String _progressChip(HostProjectProgress? said) => switch (said) {
    null => 'not read',
    HostProjectProgress(hasNoAddress: true) => 'Waiting for its repository',
    HostProjectProgress(waitsForToken: true) => 'Waiting for your token',
    HostProjectProgress(state: 'carried') => 'Carried',
    HostProjectProgress(state: 'pending') => 'Being put on',
    HostProjectProgress(state: 'held') => 'Held',
    HostProjectProgress(state: 'refused') => 'Refused',
    // A word of a later host, shown as it comes.
    HostProjectProgress(:final state) => state,
  };

  /// *Give it my … token…* beside [name]'s row, where [host] waits for it for [name]; given as the page's own button
  /// gives it, and offered to its Machine Admin alone.
  Command? _giveTokenFor(OrganizationView view, OrganizationHost host, String name) {
    if (!(_progress?.of(name)?.waitsForToken ?? false)) return null;
    return giveTokenCommand(
      host: host.name,
      project: name,
      forge: organizationForgeName(view),
      give: widget.onGiveToken == null ? null : (_) => unawaited(_giveToken()),
      busy: () => _acting ? 'Waiting for the machine…' : null,
      hidden: !view.holdsRoles || !host.admins.contains(view.me),
    );
  }

  /// The repositories of [name] that [host] carries, where it carries only some: each named, and taken off alone by
  /// its Machine Admin.
  List<Widget> _carriedPart(OrganizationHost host, String name, {required bool isAdmin}) => [
    if (host.repositories[name] case final repositories?)
      for (final repository in repositories)
        ListTile(
          key: ValueKey('organization.carried/$name/$repository'),
          dense: true,
          contentPadding: const EdgeInsets.only(left: Space.loose, right: Space.normal),
          leading: const Icon(Icons.source_outlined),
          title: Text(repository),
          subtitle: Text(
            [
              // Put here alone, it is carried only once the machine stops waiting for the token for it; one it has
              // taken already stays carried while it waits for another.
              switch (_takenRow(name, repository) == null
                  ? waitingWords(_progress?.of(name), organizationForgeName(widget.organization.view))
                  : null) {
                final waits? => 'Of $name, put here alone; the machine $waits',
                null => 'Of $name, carried here alone',
              },
              if (_takenRow(name, repository)?.central case final central?) central.words,
            ].join(' · '),
          ),
          trailing: !isAdmin
              ? null
              : TextButton(
                  key: ValueKey('organization.takeOffRepository/$name/$repository'),
                  onPressed: () => unawaited(
                    showDialog<void>(
                      context: context,
                      builder: (_) => takeProjectOffTheMachine(
                        widget.organization,
                        project: name,
                        machine: host.name,
                        repository: repository,
                      ),
                    ),
                  ),
                  child: const Text('Take it off this machine…'),
                ),
        ),
  ];

  HostRepositoryProgress? _takenRow(String name, String repository) => _progress
      ?.of(name)
      ?.repositories
      .where((row) => row.repository == repository && row.state == 'taken')
      .firstOrNull;

  /// Each taken repository's central state, and the ones not taken by reason; a repository carried here alone says its
  /// central state on its own row.
  List<Widget> _repositoryProgress(OrganizationHost host, String name) {
    final carriedAlone = host.repositories[name] ?? const <String>[];
    final byState = <String, List<HostRepositoryProgress>>{};
    final progress = _progress?.of(name);
    if (progress == null) return const [];
    for (final each in progress.repositories) {
      if (progress.state == 'carried' && each.state != 'taken') (byState[each.state] ??= []).add(each);
    }
    return [
      for (final row in progress.repositories)
        if (row.state == 'taken' && !carriedAlone.contains(row.repository))
          ListTile(
            key: ValueKey('organization.central/$name/${row.repository}'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.normal),
            title: Text(row.repository),
            subtitle: Text((row.central ?? const HostRepositoryCentral()).words),
          ),
      for (final MapEntry(key: state, value: rows) in byState.entries)
        ExpansionTile(
          key: ValueKey('organization.notTaken/$name/$state'),
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: Space.normal),
          childrenPadding: const EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(switch (state) {
            'no-central' =>
              '${_count(rows.length)} ${rows.length == 1 ? 'names' : 'name'} no central address, so the machine does not take ${rows.length == 1 ? 'it' : 'them'}',
            'waiting' => '${_count(rows.length)} still to be taken',
            _ => '${_count(rows.length)}: $state',
          }),
          children: [
            Text(rows.map((each) => each.repository).join(', ')),
            for (final why in {for (final each in rows) ?each.why})
              Text(why, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ];
  }

  /// What a fetch that was not refused came to, in the machine's own answer.
  String _fetchedWords(String name, HostProgress? fetched) => switch (fetched) {
    HostProgress(refused: final refused?) => '$name did not apply the organization: $refused',
    HostProgress(wantsToken: true) => '$name fetched the organization and waits for your token.',
    _ => '$name fetched and applied the organization.',
  };

  String _count(int n) => n == 1 ? '1 repository' : '$n repositories';

  /// The host's own word on [name], which only a host admin reads: the organization's word is carried or not.
  String? _progressWords(OrganizationView view, OrganizationHost host, String name) {
    final progress = _progress?.of(name);
    if (progress == null) return null;
    if (progress.hasNoAddress) {
      return "the machine has no address for it: a token cannot help until the project's admin creates its Git repository or files its "
          'address anew, and it then needs your token once more';
    }
    // Where it says each repository, the ones on the machine are named first; the rest are its own lines below.
    if (progress.state == 'carried' && progress.repositories.isNotEmpty) {
      return progress.taken.isEmpty
          ? 'on the machine, none of its repositories taken yet'
          : 'on the machine: ${progress.taken.join(', ')}';
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

  Widget _admins(
    OrganizationView view,
    OrganizationHost host,
    bool isAdmin, {
    List<LeafPathStep> path = const [],
    List<Widget> beforeRows = const [],
  }) {
    final candidates = [
      for (final person in view.holdingRoles)
        if (!host.admins.contains(person.login)) person.login,
    ];
    return FilteredListSection(
      title: 'Machine Admins',
      leaf: true,
      path: path,
      beforeRows: beforeRows,
      subtitle: counted(host.admins.length, 'Machine Admin', 'Machine Admins'),
      storageId: 'host-admins ${host.name}',
      greyWords: [
        if (view.mayNameAdminsOf(host) && candidates.isEmpty)
          'Add a Machine Admin: everyone holding a role in the organization is one already.',
      ],
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
            child: ItemListRow(
              leading: const Icon(Icons.shield_outlined),
              title: admin == view.me ? '$admin (you)' : admin,
              subtitleMaxLines: null,
              state: _standing(view, admin),
              onOpen: null,
              subtitle: [
                _standing(view, admin),
                if (host.adminKeys.any((key) => key.login == admin && key.backup)) 'has a backup key',
              ].join(' · '),
              // The last host admin cannot be removed, so nothing offers it.
              menu: view.mayNameAdminsOf(host) && host.admins.length > 1
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
    final isUp = connections?.up(host.name) ?? false;
    final waits = (_progress?.waitsForToken ?? false) || (connections?.waitsForToken(host.name) ?? false);
    final ready = connected && isUp && !waits;
    // Kept here with its connection down: that is what Connect is for, as on the row.
    final isDown = connected && !isUp && !waits;
    final why = _whyNotConnect(host, connections);
    // A project the machine waits for a token for, with nothing of it taken, is never ready to work on, whatever is
    // listed; one with some of it taken is, while it waits for the rest.
    final waiting = {
      for (final said in _progress?.projects ?? const <HostProjectProgress>[])
        if ((said.waitsForToken || said.hasNoAddress) && said.taken.isEmpty) said.project,
    };
    final mine = [
      for (final project in view.projects)
        // A project carried in part may be on this machine and another, and the store names one host for it.
        if ((project.host == host.name || host.projects.contains(project.name)) &&
            !view.saysNoRepository(project) &&
            !waiting.contains(project.name) &&
            (project.admins.contains(view.me) || project.members.contains(view.me)))
          project.name,
    ];
    final name = host.name;
    final forge = openHostForgeCommand(host: name, connections: connections, hasForge: host.webPort != null);
    final readNow = readOrganizationNowCommand(host: name, connections: connections);
    final buttons = [
      if (ready && widget.onStartWork != null)
        AskingButton(
          key: const ValueKey('asking startWork'),
          buttonKey: ValueKey('organization.startWork/$name'),
          answerKey: const ValueKey('organization.startWhy'),
          filled: true,
          waiting: 'Starting work on $name, which can take a minute while it takes the project…',
          first: () => _chooseWhereToStart(mine),
          onAsk: _acting ? null : () => _startWork(name),
          label: Text(switch (mine) {
            [] => 'Start work',
            [final one] => 'Start work in $one',
            _ => 'Start work…',
          }),
        ),
      if (connected)
        AskingButton(
          key: const ValueKey('asking disconnect'),
          buttonKey: ValueKey('organization.disconnect/$name'),
          answerKey: const ValueKey('organization.connectWhy'),
          waiting: 'Disconnecting from $name…',
          onAsk: _acting ? null : () => _act(() => connections!.disconnect(name), byAButton: true),
          label: const Text('Disconnect'),
        ),
      if ((!connected || isDown) && view.myHosts.contains(host))
        AskingButton(
          key: const ValueKey('asking connect'),
          buttonKey: ValueKey('organization.connect/$name'),
          answerKey: const ValueKey('organization.connectWhy'),
          filled: true,
          waiting: 'Connecting to $name…',
          onAsk: _acting || why != null ? null : () => _act(() => connections!.connect(name), byAButton: true),
          label: const Text('Connect'),
        ),
      Tooltip(
        message: forge.unavailable ?? 'Open the forge of $name in the browser',
        child: AskingButton(
          key: const ValueKey('asking openForge'),
          buttonKey: ValueKey('organization.openForge/$name'),
          answerKey: const ValueKey('organization.forgeWhy'),
          waiting: _forgeAnswers == false
              ? "Raising this computer's forward to $name anew, then opening its forge…"
              : 'Opening the forge of $name…',
          onAsk: _acting || !forge.available ? null : _openForge,
          label: Text(forge.label),
        ),
      ),
      if (connected)
        Tooltip(
          message:
              readNow.unavailable ??
              'Have $name read the organization now, rather than at its next round within five minutes',
          child: AskingButton(
            key: ValueKey('asking readNow/$name'),
            buttonKey: ValueKey('organization.readNow/$name'),
            answerKey: const ValueKey('organization.readNowWhy'),
            waiting: '$name reads the organization, which can take some minutes…',
            onAsk: _acting || !readNow.available ? null : () => _readNow(name),
            label: Text(readNow.label),
          ),
        ),
      if (!ready && !_acting)
        if (connections case final held?) LastConnectAttempt(held, name),
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
                      '${waiting.isEmpty ? '' : ' Waiting before $name takes them: ${waiting.join(', ')}.'}'
                : isDown
                ? 'Not connected now: the connection to $name is down. Connect brings it back.'
                : connected
                ? 'Not connected yet. $name makes your account once it has read the organization, up to five minutes after '
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
          if (_forgeAnswers == false)
            Text(
              key: const ValueKey('organization.forgeDead'),
              _raisedInVain
                  ? "The host's forge still gives no answer through this computer's forward, raised anew: its cause is "
                        'on the host.'
                  : "The host's forge gives no answer through this computer's forward. Open its forge raises the "
                        'forward anew before it opens.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: Space.small),
          Wrap(spacing: Space.small, runSpacing: Space.small, children: buttons),
          if (forge.unavailable case final why?)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                key: const ValueKey('organization.noForgeWhy'),
                'Open its forge: $why',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (connected && readNow.unavailable != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                key: const ValueKey('organization.noReadNowWhy'),
                '${readNow.label}: ${readNow.unavailable}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          // Where *Start work* is not offered, what stands in its way, said once beside where it would be.
          if (!ready && widget.onStartWork != null && view.myHosts.contains(host))
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                key: const ValueKey('organization.noStartWhy'),
                'Start work comes ${!connected
                    ? 'once this computer is connected to $name'
                    : isDown
                    ? 'once the connection to $name is up again'
                    : 'once $name has made your account, after its Machine Admin gave it the token'}.',
              ),
            ),
        ],
      ),
    );
  }

  /// Starts work from this page in what the person has here: the one project, or the one they choose among several.
  /// The way into `default` is taken only with no project here, or by its name.
  /// Which project a press of *Start work* starts in, chosen before the machine is asked: the one, or the one chosen
  /// among several. Answers whether to go on.
  Future<bool> _chooseWhereToStart(List<String> mine) async {
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
      if (chosen == null) return false;
      _startIn = chosen == defaultProject ? null : chosen;
    } else {
      _startIn = mine.firstOrNull;
    }
    return true;
  }

  /// Has [host] read the organization now, then reads what it says of itself at once, where its Machine Admin may;
  /// answers the host's words of the read, or its refusal.
  Future<String?> _readNow(String host) async {
    final connections = widget.connections;
    if (connections == null) return null;
    String? words;
    final refused = await _act(() async => words = await connections.followNow(host), byAButton: true);
    // Greyed now, its reason stands once, beside the action, not twice.
    if (connections.whyNotFollowNow(host) != null) return null;
    if (refused != null) return refused;
    if (!mounted || !_isAdminHere || !connections.connected(host)) return words;
    final unread = await _read(() => connections.progress(host), byAButton: true);
    return unread == null ? words : '$words How it stands now could not be read: $unread';
  }

  /// Where the last choice said to start; null is Default.
  String? _startIn;

  /// Starts work, the page busy meanwhile, so nothing else is asked of the machine at once.
  Future<String?> _startWork(String host) async {
    setState(() => _working++);
    try {
      return await widget.onStartWork?.call(host, _startIn);
    } finally {
      if (mounted) setState(() => _working--);
    }
  }
}

/// Asks for a host's address, port and host key, which its host admin enters.
/// Enters a machine's address and SSH host key by hand, or changes them.
class HostAddressDialog extends StatefulWidget {
  /// Asks [organization] to file them for [host].
  const HostAddressDialog(this.organization, this.host, {super.key});

  /// The organization the change is asked of.
  final Organization organization;

  /// The machine.
  final OrganizationHost host;

  @override
  State<HostAddressDialog> createState() => _HostAddressDialogState();
}

class _HostAddressDialogState extends State<HostAddressDialog> {
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
    confirm: widget.host.hasNoReach ? 'Enter them' : 'Change them',
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

/// What a machine an organization's card names says of itself, read for a page that shows part of it: asked only of
/// its connected Machine Admin, again as the connection comes up, and said as not read, with why, otherwise.
class HostProgressReading extends StatefulWidget {
  /// Reads [host] through [connections] for [builder].
  const HostProgressReading({
    required this.organization,
    required this.connections,
    required this.host,
    required this.builder,
    super.key,
  });

  /// The organization, which says who the machine's Machine Admins are.
  final Organization organization;

  /// This person's connections, absent where this computer has none.
  final HostConnections? connections;

  /// The machine's name on its card.
  final String host;

  /// Builds from what the machine said, null where it was not read, and why it was not, where it was not.
  final Widget Function(BuildContext context, HostProgress? progress, String? why) builder;

  @override
  State<HostProgressReading> createState() => _HostProgressReadingState();
}

class _HostProgressReadingState extends State<HostProgressReading> {
  HostProgress? _progress;
  String? _refused;
  bool _asked = false;
  int _reads = 0;

  @override
  void initState() {
    super.initState();
    widget.connections?.addListener(_heard);
    widget.organization.addListener(_ask);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ask();
    });
  }

  @override
  void dispose() {
    widget.connections?.removeListener(_heard);
    widget.organization.removeListener(_ask);
    super.dispose();
  }

  /// The connections changed, or the machine was heard again from anywhere, as after its token was given: shown here.
  void _heard() {
    _ask();
    if (mounted) setState(() {});
  }

  /// Why the machine is not asked, or null where it is.
  String? get _notAsked {
    final view = widget.organization.view;
    final host = view?.hosts.where((each) => each.name == widget.host).firstOrNull;
    if (view == null || host == null) return 'The organization has not been read, so ${widget.host} was not asked.';
    if (!view.holdsRoles || !host.admins.contains(view.me)) {
      return 'Only a connected Machine Admin of ${widget.host} reads what it carries and how it stands with central.';
    }
    if (!(widget.connections?.connected(widget.host) ?? false)) {
      return 'Connect to ${widget.host} to read what it carries and how it stands with central.';
    }
    return null;
  }

  void _ask() {
    if (_notAsked != null) {
      _asked = false;
      if (mounted) setState(() {});
      return;
    }
    if (_asked) return;
    _asked = true;
    // What the machine said already, wherever it was asked, is taken rather than asked again as root.
    if (widget.connections?.heard(widget.host) != null) return;
    unawaited(_read());
  }

  Future<void> _read() async {
    final read = ++_reads;
    HostProgress? progress;
    String? refused;
    try {
      progress = await widget.connections!.ask(widget.host);
    } on OrganizationRefused catch (refusal) {
      refused = refusal.words;
    }
    if (!mounted || read != _reads) return;
    setState(() {
      _progress = progress;
      _refused = refused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final why = _notAsked ?? (_refused == null ? null : '${widget.host} did not say how it stands: $_refused');
    // What the machine said last, wherever it was asked: after its token was given, it no longer waits here either.
    final progress = why == null ? (widget.connections?.heard(widget.host) ?? _progress) : null;
    return widget.builder(
      context,
      progress,
      why ?? (progress == null ? 'Waiting for ${widget.host} to say what it carries.' : null),
    );
  }
}
