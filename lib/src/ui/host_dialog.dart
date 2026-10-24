import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;

import '../app/desk.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import '../app/session.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Puts [project] on a server, or takes it off again, by the `porelo-host` shipped beside this
/// interface, showing each step as it says it and asking at its one stop.
Future<void> openHostDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  StartHostCommand? start,
  required Settings settings,
}) => showDialog<void>(
  context: context,
  builder: (context) => HostDialog(project: project, machines: machines, start: start, settings: settings),
);

/// The page: where it goes, the steps, and at the stop what only the person can give.
///
/// Secrets are typed only into the host terminal, in the provider and vault prompts. The
/// provider key belongs to the system store (`porelo-host key set scaleway`).
class HostDialog extends StatefulWidget {
  /// Constructor taking the project and, for the tests, how the command is started.
  const HostDialog({
    required this.project,
    required this.machines,
    this.start,
    this.openTerminal,
    this.environment,
    this.settings,
    this.secretStore,
    this.pickFolder,
    this.pickFile,
    this.saveTunnel,
    super.key,
  });

  /// The project to put on a server.
  final String project;

  /// Starts the command; the shipped one when null.
  final StartHostCommand? start;

  /// Opens the host terminal; replaceable without a real SSH process in tests.
  final OpenTerminal? openTerminal;

  /// Overrides command selection for a development walk.
  final Map<String, String>? environment;

  /// The fleet to add the completed host to and remove it from.
  final Machines machines;

  /// The interface's project-specific folder choices.
  final Settings? settings;

  /// An injected store for tests; otherwise opened and closed for each operation.
  final SecretStore? secretStore;

  /// System pickers, replaceable without platform calls in widget tests.
  final Future<String?> Function()? pickFolder;

  /// Chooses a path file without opening a platform dialog in tests.
  final Future<String?> Function()? pickFile;

  /// Chooses the explicitly requested tunnel export destination.
  final Future<String?> Function()? saveTunnel;

  @override
  State<HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends State<HostDialog> {
  final _scaleway = TextEditingController();
  final _tresor = TextEditingController();
  final _account = TextEditingController(text: 'porelo');
  final _publicKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _identity = TextEditingController(text: _home('.ssh/id_ed25519'));
  final _collection = TextEditingController();
  final _email = TextEditingController();
  final _repository = TextEditingController();
  final _signingKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _keyName = TextEditingController();
  final _keys = <HostKeyFile>[];
  final _scroll = ScrollController();
  final _stopStart = GlobalKey();
  bool _stopShown = false;
  String? _folder;
  HostTunnel? _tunnel;
  bool _preparing = false;
  HostSession? _session;

  @override
  void initState() {
    super.initState();
    _folder = widget.settings?.tresorFolder(widget.project);
  }

  bool _upStarted = false;
  bool _doneUp = false;
  bool _showTunnel = false;
  bool _saving = false;
  bool _terminalOpen = false;
  String? _machineProblem;

  static String _home(String relativePath) => desk.expandHome('~/$relativePath');

  @override
  void dispose() {
    for (final field in <TextEditingController>[
      _repository,
      _signingKey,
      _keyName,
      _scaleway,
      _tresor,
      _account,
      _publicKey,
      _identity,
      _collection,
      _email,
    ]) {
      field.dispose();
    }
    _session?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted) return;
    final waiting = _session?.state == HostRunState.waiting;
    setState(() {});
    if (waiting && !_stopShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _session?.state != HostRunState.waiting) return;
        final stop = _stopStart.currentContext;
        if (stop != null) unawaited(Scrollable.ensureVisible(stop));
      });
    }
    _stopShown = waiting;
  }

  void _expandPaths() {
    final fields = [_publicKey, _identity, _collection, _signingKey];
    final expanded = [for (final field in fields) desk.expandHome(field.text.trim())];
    for (var i = 0; i < fields.length; i++) {
      fields[i].text = expanded[i];
    }
  }

  HostSession _newSession() {
    _session?.dispose();
    final session = HostSession(
      executable: poreloHost(environment: widget.environment),
      arguments: <String>[
        '--project',
        widget.project,
        '--tresor',
        _tresor.text.trim(),
        '--account',
        _account.text.trim(),
        '--public-key',
        _publicKey.text.trim(),
        '--identity',
        _identity.text.trim(),
        '--collection',
        _collection.text.trim(),
        if (_tunnel != null) ..._tunnel!.arguments,
        '--scaleway-project',
        _scaleway.text.trim(),
      ],
      start: widget.start,
    )..addListener(_sessionChanged);
    return _session = session;
  }

  bool get _complete => <TextEditingController>[
    _scaleway, _tresor, _account, _publicKey, _identity, _collection, //
  ].every((field) => field.text.trim().isNotEmpty);

  String? get _tunnelEndpoint {
    final address = _session?.address;
    if (address == null || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address)) return null;
    return address.contains(':') ? '[$address]:51820' : '$address:51820';
  }

  bool get _running => _preparing || _saving || _terminalOpen || _session?.state == HostRunState.running;

  Future<void> _withFiles(Future<void> Function(HostFiles) use) async {
    late final SecretStore store;
    try {
      store = widget.secretStore ?? SecretStore.forThisSystem();
    } on Exception {
      throw const SecretStoreFailed('The system secret store could not be opened.');
    }
    try {
      await use(HostFiles(store));
    } finally {
      if (widget.secretStore == null) {
        try {
          await store.close();
        } on Exception {
          throw const SecretStoreFailed('The system secret store could not be closed.');
        }
      }
    }
  }

  Future<void> _chooseFolder() async {
    final folder = await (widget.pickFolder?.call() ?? getDirectoryPath());
    if (folder == null || !mounted) return;
    await widget.settings?.rememberTresorFolder(widget.project, folder);
    if (mounted) {
      setState(() {
        _folder = folder;
        _machineProblem = null;
      });
    }
  }

  Future<void> _addKey() async {
    try {
      HostFiles.checkName(_keyName.text);
      final file = await _pickFile();
      if (file == null || !mounted) return;
      HostFiles.checkBasename(path.basename(file));
      final key = HostKeyFile(_keyName.text, File(file));
      setState(() {
        _keys.add(key);
        _keyName.clear();
      });
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    }
  }

  Future<String?> _pickFile() async => widget.pickFile == null ? (await openFile())?.path : await widget.pickFile!();

  Future<void> _chooseFile(TextEditingController field) async {
    final file = await _pickFile();
    if (file != null && mounted) setState(() => field.text = file);
  }

  Future<void> _up() async {
    if (_running) return;
    setState(() {
      _preparing = true;
      _machineProblem = null;
    });
    try {
      _expandPaths();
      if (!_upStarted) {
        await _withFiles((files) async {
          _tunnel = await files.prepare(
            project: widget.project,
            folder: _folder,
            url: _repository.text,
            signingKey: File(_signingKey.text.trim()),
            keys: _keys,
          );
        });
        if (!mounted) return;
        _newSession();
        _upStarted = true;
      }
      await _runUp(_session!.up);
    } on FormatException catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _machineProblem = 'Cannot prepare the host file: ${error.path ?? "selected file"}.');
    } on SecretStoreFailed {
      if (mounted) {
        setState(() => _machineProblem = 'The system secret store could not keep or read the WireGuard key.');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _exportTunnel() async {
    try {
      final path = widget.saveTunnel == null
          ? (await getSaveLocation(suggestedName: 'porelo.conf'))?.path
          : await widget.saveTunnel!();
      if (path == null || !mounted) return;
      setState(() => _saving = true);
      await _withFiles(
        (files) => files.exportTunnel(
          project: widget.project,
          tunnel: _tunnel!,
          address: _session!.address ?? '',
          destination: File(path),
        ),
      );
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _machineProblem = 'Cannot save the tunnel file: ${error.path ?? "selected file"}.');
    } on SecretStoreFailed {
      if (mounted) setState(() => _machineProblem = 'The system secret store could not read the WireGuard key.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Keep the rented host's identity so teardown cannot silently target a different host.
  Future<void> _down() async {
    try {
      _expandPaths();
    } on FormatException catch (error) {
      setState(() => _machineProblem = error.message);
      return;
    }
    _doneUp = false;
    _showTunnel = false;
    _machineProblem = null;
    final account = _account.text.trim();
    if (!_upStarted) {
      setState(() => _preparing = true);
      try {
        await _withFiles((files) async {
          _tunnel = await files.prepare(project: widget.project, url: '', signingKey: File(''));
        });
      } on HostFilesRefused catch (error) {
        if (mounted) setState(() => _machineProblem = error.message);
        return;
      } on SecretStoreFailed {
        if (mounted) setState(() => _machineProblem = 'The system secret store could not read the WireGuard key.');
        return;
      } finally {
        if (mounted) setState(() => _preparing = false);
      }
      if (!mounted) return;
    }
    final session = _upStarted ? _session! : _newSession();
    await session.down();
    if (session.state != HostRunState.done) return;
    final address = session.releasedAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _machineProblem = 'No host was found. Your machines have been kept.');
      return;
    }
    for (final machine in widget.machines.all) {
      if (machine.kind == 'host' && machine.host == '$account@$address') {
        await widget.machines.forget(machine);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _runUp(Future<void> Function() run) async {
    _doneUp = false;
    _showTunnel = false;
    _machineProblem = null;
    await run();
    if (mounted) {
      setState(() {
        _doneUp = _session!.state == HostRunState.done;
        _showTunnel = _doneUp;
      });
    }
  }

  Future<void> _addHost() async {
    final session = _session!;
    final address = session.address ?? '';
    final account = session.account ?? '';
    final socket = session.socket ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account) ||
        !RegExp(r'^/run/user/[0-9]+/porelo/porelod\.sock$').hasMatch(socket)) {
      setState(() => _machineProblem = 'The completed host did not name a valid address, account and daemon socket.');
      return;
    }
    final name = '${widget.project} server';
    if (widget.machines.all.any((machine) => machine.name == name && machine.kind != 'host')) {
      setState(() => _machineProblem = 'A machine named $name already exists and is not a host.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.machines.add(
        Machine(
          name: name,
          kind: 'host',
          socketPath: Platform.isWindows ? '' : Machine.endpointFor(name),
          host: '$account@$address',
          remoteSocket: socket,
          identity: _identity.text.trim(),
        ),
      );
      if (mounted) setState(() => _doneUp = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openHostTerminal() async {
    final session = _session!;
    final String line;
    try {
      line = hostStopCommand(session.needs, email: _email.text);
    } on FormatException catch (error) {
      setState(() => _machineProblem = error.message);
      return;
    }
    final address = session.address ?? '';
    final account = session.account ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(account)) {
      setState(() => _machineProblem = 'The host stop did not name a valid address and account.');
      return;
    }
    final machine = Machine(
      name: '${widget.project} server',
      socketPath: '',
      kind: 'host',
      host: '$account@$address',
      identity: _identity.text.trim(),
    );
    setState(() {
      _terminalOpen = true;
      _machineProblem = null;
    });
    try {
      await runInATerminal(
        context,
        title: 'Complete setup on ${machine.name}',
        explanation: 'Type the secrets into the host commands here. Close the terminal when finished; host setup will check what is still needed.',
        machine: machine,
        command: <String>[openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host, inTheLoginShell(line)],
        open: widget.openTerminal,
      );
      if (mounted) await _runUp(session.up);
    } finally {
      if (mounted) setState(() => _terminalOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return AlertDialog(
      title: Text('Put ${widget.project} on a server'),
      content: SizedBox(
        width: Sizes.dialogMedium,
        child: DialogScroll(
          controller: _scroll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Porelo rents a server from Scaleway Elastic Metal, or finds it again, and sets it up '
                'there. It uses the access key saved with porelo-host key set scaleway.',
              ),
              if (Platform.isWindows)
                const Text('The server setup files and saved VPN connection can be read only by your Windows user.'),
              const SizedBox(height: Space.normal),
              if (_folder != null)
                Text('Project tresor folder on this computer: $_folder')
              else
                const Text(
                  'No local Tresorit folder chosen. Copy machine.yml, wireguard.key and any keys/ files into the project tresor under porelo-host/ before the host reads them.',
                ),
              TextButton(
                key: const Key('host-folder'),
                onPressed: _running || _upStarted ? null : _chooseFolder,
                child: Text(_folder == null ? 'Choose the project tresor folder on this computer' : 'Choose another'),
              ),
              _field(_scaleway, 'Scaleway project id', 'host-scaleway-project', namesHost: true),
              _field(_tresor, 'The project\'s tresor', 'host-tresor', namesHost: true),
              if (_folder != null) ...<Widget>[
                _field(_repository, 'Project repository address', 'host-repository', namesHost: true),
                _pathField(_signingKey, 'Public key for signing commits (.pub)', 'host-signing-key'),
                _field(_keyName, 'Optional vault entry name', 'host-key-name', namesHost: true),
                TextButton(
                  onPressed: _running || _upStarted ? null : _addKey,
                  child: const Text('Choose a file for this vault entry'),
                ),
                for (final key in _keys)
                  Row(
                    children: <Widget>[
                      Expanded(child: Text('${key.name}: ${key.basename}')),
                      IconButton(
                        onPressed: _running || _upStarted ? null : () => setState(() => _keys.remove(key)),
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove this file',
                      ),
                    ],
                  ),
              ],
              _field(_account, 'Account on the server', 'host-account', namesHost: true),
              _pathField(_publicKey, 'Your public ssh key', 'host-public-key'),
              _pathField(_identity, 'Your private ssh key', 'host-identity'),
              _pathField(_collection, 'Server setup file (.tar.gz)', 'host-collection'),
              const SizedBox(height: Space.normal),
              if (session != null) ...<Widget>[
                for (final step in session.steps) _stepRow(step),
                if (session.state == HostRunState.waiting) _askForTheStop(session.needs),
                if (session.fix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(
                      session.fix!,
                      key: const Key('host-fix'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (session.state == HostRunState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.small),
                    child: Text('Done.', key: Key('host-done')),
                  ),
              ],
              if (_machineProblem != null) Text(_machineProblem!),
              if (_showTunnel) ...<Widget>[
                Text(
                  _tunnel?.hostPublicKey.isNotEmpty == true
                      ? 'Host public key: ${_tunnel!.hostPublicKey}\nEndpoint: ${_tunnelEndpoint ?? 'unavailable'}\nAllowedIPs = 10.73.0.1/32\nAddress = 10.73.0.2/24'
                      : 'The host public key is unavailable here because the host files were supplied manually.',
                ),
                Wrap(
                  spacing: Space.small,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    TextButton(
                      key: const Key('host-export-tunnel'),
                      onPressed: _running || _tunnel?.hostPublicKey.isNotEmpty != true || _tunnelEndpoint == null
                          ? null
                          : _exportTunnel,
                      child: const Text('Save the VPN connection to this server'),
                    ),
                    const Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          'WireGuard makes an encrypted VPN connection between this computer and the server. '
                          'This file holds a private key. Keep it in a private folder that only you can read; do not share it. '
                          'Use WireGuard installed on this computer to connect. Administrator (root) access is needed. '
                          'Replace <file> with the saved file path and run:\n'
                          'cat <file> | sudo tee /etc/wireguard/porelo.conf\n'
                          'sudo wg-quick up porelo',
                      child: Padding(padding: EdgeInsets.all(Space.small), child: Icon(Icons.info_outline)),
                    ),
                  ],
                ),
              ],
              if (_doneUp)
                FilledButton(
                  key: const Key('host-add'),
                  onPressed: _running ? null : _addHost,
                  child: const Text('Add this server to your machines'),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _running ? null : () => Navigator.of(context).pop(), child: const Text('Close')),
        OutlinedButton(
          key: const Key('host-down'),
          onPressed: _running || !_complete ? null : _down,
          child: const Text('Take it off the server'),
        ),
        FilledButton(
          key: const Key('host-up'),
          onPressed: _running || !_complete ? null : _up,
          child: const Text('Put it on a server'),
        ),
      ],
    );
  }

  Widget _pathField(TextEditingController controller, String label, String key) => Row(
    children: <Widget>[
      Expanded(child: _field(controller, label, key, namesHost: true)),
      const SizedBox(width: Space.small),
      TextButton(
        onPressed: _running || _upStarted ? null : () => _chooseFile(controller),
        child: const Text('Choose…'),
      ),
    ],
  );

  Widget _field(TextEditingController controller, String label, String key, {bool namesHost = false}) => Padding(
    padding: const EdgeInsets.only(bottom: Space.small),
    child: TextField(
      key: Key(key),
      controller: controller,
      enabled: !_running,
      readOnly: namesHost && _upStarted,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _stepRow(Step step) => Row(
    key: Key('host-step-${step.step}'),
    children: <Widget>[
      Icon(switch (step.state) {
        StepState.started => Icons.pending_outlined,
        StepState.done => Icons.check,
        StepState.refused => Icons.error_outline,
        StepState.waiting => Icons.person_outline,
      }, size: Sizes.mark),
      const SizedBox(width: Space.small),
      Expanded(child: Text(step.step)),
    ],
  );

  /// The host names the steps; their own prompts take every secret in its terminal.
  Widget _askForTheStop(List<String> needs) {
    final drive = needs.contains('drive');
    const known = <String>{'drive', 'vault', 'vault-new'};
    final unknown = needs.where((need) => !known.contains(need)).toList();
    final prompts = <Widget>[
      if (needs.isEmpty)
        const Text('The host waits without saying for what.')
      else ...<Widget>[
        if (drive) const Text('The host needs a Tresorit login.'),
        if (needs.contains('vault-new')) const Text('The host needs a passphrase for its new vault.'),
        if (needs.contains('vault')) const Text('The host needs its vault unlocked.'),
      ],
      for (final need in unknown) Text('porelo-host waits for $need; this interface cannot answer it yet.'),
    ];
    return Column(
      key: const Key('host-stop'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.normal),
        KeyedSubtree(key: _stopStart, child: prompts.first),
        ...prompts.skip(1),
        if (drive) _field(_email, 'Tresorit e-mail', 'host-drive-email'),
        if (needs.isNotEmpty && unknown.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('host-open-terminal'),
              onPressed: _running ? null : _openHostTerminal,
              child: const Text('Open a terminal on the host'),
            ),
          ),
      ],
    );
  }
}
