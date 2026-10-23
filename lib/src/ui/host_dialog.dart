import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;

import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

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
/// **Drive and vault answers are not kept.** The answers go to the command's standard input when sent and
/// the fields are cleared; the provider's key is not asked here, it is the system store's
/// (`porelo-host key set scaleway`).
class HostDialog extends StatefulWidget {
  /// Constructor taking the project and, for the tests, how the command is started.
  const HostDialog({
    required this.project,
    required this.machines,
    this.start,
    this.settings,
    this.secretStore,
    this.pickFolder,
    this.saveTunnel,
    super.key,
  });

  /// The project to put on a server.
  final String project;

  /// Starts the command; the shipped one when null.
  final StartHostCommand? start;

  /// The fleet to add the completed host to and remove it from.
  final Machines machines;

  /// The interface's project-specific folder choices.
  final Settings? settings;

  /// An injected store for tests; otherwise opened and closed for each operation.
  final SecretStore? secretStore;

  /// System pickers, replaceable without platform calls in widget tests.
  final Future<String?> Function()? pickFolder;

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
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _passphrase = TextEditingController();
  final _again = TextEditingController();
  final _repository = TextEditingController();
  final _signingKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _keyName = TextEditingController();
  final _keys = <HostKeyFile>[];
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
  String? _machineProblem;

  static String _home(String relativePath) {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    return path.joinAll([home, ...path.posix.split(relativePath)]);
  }

  @override
  void dispose() {
    for (final field in <TextEditingController>[
      _repository, _signingKey, _keyName,
      _scaleway,
      _tresor,
      _account,
      _publicKey,
      _identity,
      _collection,
      _email,
      _password,
      _code,
      _passphrase,
      _again, //
    ]) {
      field.dispose();
    }
    _session?.dispose();
    super.dispose();
  }

  HostSession _newSession() {
    _session?.dispose();
    final session = HostSession(
      executable: shippedPoreloHost(),
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
    )..addListener(() => setState(() {}));
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

  bool get _running => _preparing || _saving || _session?.state == HostRunState.running;

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
      final file = await openFile();
      if (file == null || !mounted) return;
      HostFiles.checkBasename(path.basename(file.path));
      final key = HostKeyFile(_keyName.text, File(file.path));
      setState(() {
        _keys.add(key);
        _keyName.clear();
      });
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    }
  }

  Future<void> _up() async {
    if (_running) return;
    setState(() {
      _preparing = true;
      _machineProblem = null;
    });
    try {
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

  void _resume() {
    final needs = _session!.needs;
    final answers = Answers(
      driveEmail: needs.contains('drive') ? _email.text.trim() : null,
      drivePassword: needs.contains('drive') ? _password.text : null,
      driveCode: needs.contains('drive') && _code.text.trim().isNotEmpty ? _code.text.trim() : null,
      vaultPassphrase: needs.any((n) => n.startsWith('vault')) ? _passphrase.text : null,
    );
    // Gone from the fields before the command even starts: the answers live only in what is sent.
    _password.clear();
    _code.clear();
    _passphrase.clear();
    _again.clear();
    unawaited(_runUp(() => _session!.resume(answers)));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return AlertDialog(
      title: Text('Put ${widget.project} on a server'),
      content: SizedBox(
        width: Sizes.dialogMedium,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'porelo-host rents the host at Scaleway Elastic Metal, or finds it again, and runs the '
                'playbook there. Its key is the one `porelo-host key set scaleway` kept.',
              ),
              if (Platform.isWindows)
                const Text('The host files and tunnel export are restricted to your Windows user.'),
              const SizedBox(height: Space.normal),
              _field(_scaleway, 'Scaleway project id', 'host-scaleway-project', namesHost: true),
              _field(_tresor, 'The project\'s tresor', 'host-tresor', namesHost: true),
              Text(
                _folder ?? 'No local Tresorit folder chosen. Copy machine.yml, wireguard.key and any keys/ files into the project tresor under porelo-host/ before the host reads them.',
              ),
              TextButton(
                key: const Key('host-folder'),
                onPressed: _running || _upStarted ? null : _chooseFolder,
                child: const Text('Choose the project tresor folder on this computer'),
              ),
              if (_folder != null) ...<Widget>[
                _field(_repository, 'Project repository URL', 'host-repository', namesHost: true),
                _field(_signingKey, 'Commit-signing public key (.pub path)', 'host-signing-key', namesHost: true),
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
              _field(_account, 'Account on the host', 'host-account', namesHost: true),
              _field(_publicKey, 'Your public ssh key', 'host-public-key', namesHost: true),
              _field(_identity, 'Your private ssh key', 'host-identity', namesHost: true),
              _field(_collection, 'porelo-host collection (.tar.gz)', 'host-collection', namesHost: true),
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
                const Text('Bring the tunnel up with your own WireGuard. This needs root.'),
                TextButton(
                  key: const Key('host-export-tunnel'),
                  onPressed: _running || _tunnel?.hostPublicKey.isNotEmpty != true || _tunnelEndpoint == null
                      ? null
                      : _exportTunnel,
                  child: const Text('Save the wg-quick file'),
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

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool secret = false,
    bool namesHost = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.small),
    child: TextField(
      key: Key(key),
      controller: controller,
      obscureText: secret,
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

  /// What only the person can give at the stop: the drive's login and the vault's passphrase.
  Widget _askForTheStop(List<String> needs) {
    final drive = needs.contains('drive');
    final fresh = needs.contains('vault-new');
    final vault = fresh || needs.contains('vault');
    const known = <String>{'drive', 'vault', 'vault-new'};
    final unknown = needs.where((need) => !known.contains(need)).toList();
    final matches = !fresh || _passphrase.text == _again.text;
    final given =
        (!drive || (_email.text.trim().isNotEmpty && _password.text.isNotEmpty)) &&
        (!vault || _passphrase.text.isNotEmpty) &&
        matches;
    return Column(
      key: const Key('host-stop'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.normal),
        if (needs.isEmpty)
          const Text('The host waits without saying for what.')
        else
          const Text('The host waits for what only you can give. It goes to the host and is kept nowhere.'),
        for (final need in unknown) Text('porelo-host waits for $need; this interface cannot answer it yet.'),
        if (drive) ...<Widget>[
          _field(_email, 'Tresorit e-mail', 'host-drive-email'),
          _field(_password, 'Tresorit password', 'host-drive-password', secret: true),
          // Asked here, at the stop, so it is still valid when it reaches the host a moment later.
          _field(_code, 'Tresorit one-time code (empty without a second factor)', 'host-drive-code', secret: true),
        ],
        if (vault)
          _field(
            _passphrase,
            fresh ? 'A passphrase for the new vault' : 'The vault\'s passphrase',
            'host-passphrase',
            secret: true,
          ),
        if (fresh) _field(_again, 'The same passphrase again', 'host-passphrase-again', secret: true),
        if (!matches) const Text('The two passphrases differ.', key: Key('host-passphrases-differ')),
        if ((drive || vault) && unknown.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('host-resume'),
              onPressed: given ? _resume : null,
              child: const Text('Go on'),
            ),
          ),
      ],
    );
  }
}
