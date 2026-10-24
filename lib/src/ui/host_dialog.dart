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
import 'wizard.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'dialog_scroll.dart';

/// Confirms teardown and shows the host's steps using only the kept setup arguments.
Future<void> openHostTakeDownDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  required Settings settings,
  StartHostCommand? start,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      HostDialog(project: project, machines: machines, settings: settings, start: start, takeDownOnly: true),
);

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
  barrierDismissible: false,
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
    this.takeDownOnly = false,
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

  /// Shows the machine's teardown confirmation and progress without asking setup questions.
  final bool takeDownOnly;

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
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    _folder = widget.settings?.tresorFolder(widget.project);
    if (_folder != null) _tresor.text = path.basename(path.normalize(_folder!));
    final kept = widget.settings?.hostUp(widget.project);
    if (kept != null) {
      _scaleway.text = kept.scalewayProject;
      _account.text = kept.account;
      _tresor.text = kept.tresor;
      _folder = kept.folder;
      _repository.text = kept.repository;
      _signingKey.text = kept.signingKey;
      _identity.text = kept.identity;
      _publicKey.text = kept.publicKey;
      _collection.text = kept.collection;
    }
  }

  bool _upStarted = false;
  bool _takingDown = false;
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
    _session?.removeListener(_sessionChanged);
    // A confirmed leave must not dispose a notifier while its process is still answering.
    if (!_sessionActive) _session?.dispose();
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

  HostUpRecord _record() => HostUpRecord(
    scalewayProject: _scaleway.text.trim(),
    account: _account.text.trim(),
    tresor: _tresor.text.trim(),
    folder: _folder,
    repository: _repository.text.trim(),
    signingKey: _signingKey.text.trim(),
    identity: _identity.text.trim(),
    publicKey: _publicKey.text.trim(),
    collection: _collection.text.trim(),
    vpnPeerPublicKey: _tunnel?.peerPublicKey ?? '',
    vpnPeerAddress: _tunnel == null ? '' : '10.73.0.2/32',
  );

  HostSession _newSession({HostUpRecord? record}) {
    _session?.dispose();
    final session = HostSession(
      executable: poreloHost(environment: widget.environment),
      arguments: (record ?? _record()).arguments(widget.project),
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
        final previousName = _folder == null ? '' : path.basename(path.normalize(_folder!));
        if (_tresor.text.trim().isEmpty || _tresor.text == previousName) {
          _tresor.text = path.basename(path.normalize(folder));
        }
        _folder = folder;
        _machineProblem = null;
      });
    }
  }

  Future<void> _addKey() async {
    try {
      HostFiles.checkName(_keyName.text);
      final selected = await _pickFile();
      if (selected == null || !mounted) return;
      final file = desk.expandHome(selected.trim());
      HostFiles.checkBasename(path.basename(file));
      final key = HostKeyFile(_keyName.text, File(file));
      setState(() {
        _keys.add(key);
        _keyName.clear();
      });
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on FormatException catch (error) {
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
    for (final step in _steps) {
      final reason = step.check();
      if (reason != null) {
        setState(() => _machineProblem = reason);
        return;
      }
    }
    setState(() {
      _preparing = true;
      _takingDown = false;
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
        final record = _record();
        await widget.settings?.rememberHostUp(widget.project, record);
        if (!mounted) return;
        _newSession(record: record);
        _upStarted = true;
      }
      await _runUp(_session!.up);
    } on FormatException catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _machineProblem = _preparationProblem(error));
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
    if (_running) return;
    final kept = widget.settings?.hostUp(widget.project);
    if (widget.takeDownOnly && kept == null) return;
    setState(() => _takingDown = true);
    try {
      if (kept == null && !_upStarted) _expandPaths();
    } on FormatException catch (error) {
      setState(() => _machineProblem = error.message);
      return;
    }
    _doneUp = false;
    _showTunnel = false;
    _machineProblem = null;
    final account = _upStarted ? _account.text.trim() : kept?.account ?? _account.text.trim();
    if (!_upStarted && kept == null) {
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
    final session = _upStarted ? _session! : _newSession(record: kept);
    try {
      await _runHost(session.down);
    } on Exception {
      session.state = HostRunState.refused;
      if (mounted) {
        setState(() => _machineProblem = 'The host command could not complete. Your machines have been kept.');
      }
      return;
    }
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

  Future<void> _runHost(Future<void> Function() run) async {
    _sessionActive = true;
    try {
      await run();
    } finally {
      _sessionActive = false;
      if (!mounted) _session?.dispose();
    }
  }

  Future<void> _runUp(Future<void> Function() run) async {
    _doneUp = false;
    _showTunnel = false;
    _machineProblem = null;
    await _runHost(run);
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
          hostProject: widget.project,
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

  String? _required(List<TextEditingController> fields, String reason) =>
      fields.any((field) => field.text.trim().isEmpty) ? reason : null;

  String? _fileProblem(String value, String label) {
    try {
      final expanded = desk.expandHome(value.trim());
      return switch (FileSystemEntity.typeSync(expanded)) {
        FileSystemEntityType.notFound => '$label does not exist: $expanded.',
        FileSystemEntityType.file => null,
        _ => '$label is not a regular file: $expanded.',
      };
    } on FormatException catch (error) {
      return error.message;
    } on FileSystemException {
      return '$label cannot be checked: $value.';
    }
  }

  String? get _driveFilesProblem {
    final signing = _fileProblem(_signingKey.text, 'The public key for signing commits');
    if (signing != null) return signing;
    for (final key in _keys) {
      final problem = _fileProblem(key.file.path, 'The file for vault entry ${key.name}');
      if (problem != null) return problem;
    }
    return null;
  }

  String _preparationProblem(FileSystemException error) {
    final inputs = [
      (value: _signingKey.text, label: 'Public key for signing commits (.pub)', step: 'The drive'),
      (value: _identity.text, label: 'Your private ssh key', step: 'Your ssh keys'),
      (value: _publicKey.text, label: 'Your public ssh key', step: 'Your ssh keys'),
      (value: _collection.text, label: 'Server setup file (.tar.gz)', step: 'The setup file'),
      for (final key in _keys) (value: key.file.path, label: 'Vault entry ${key.name} file', step: 'The drive'),
    ];
    final failedPath = error.path;
    if (failedPath != null) {
      for (final input in inputs) {
        final expanded = desk.expandHome(input.value.trim());
        if (path.equals(path.absolute(expanded), path.absolute(failedPath))) {
          final missing = error.osError?.errorCode == 2 || (Platform.isWindows && error.osError?.errorCode == 3);
          return '${input.label} (${input.step}) ${missing ? 'does not exist' : 'cannot be read'}: $failedPath.';
        }
      }
    }
    final message = error.osError?.message ?? error.message;
    return 'Cannot prepare ${failedPath ?? 'the selected file'}: $message.';
  }

  String? get _keysProblem {
    final missing = _required([_identity, _publicKey], 'Choose both your private and public ssh keys.');
    if (missing != null) return missing;
    final problem = _fileProblem(_identity.text, 'Your private ssh key');
    if (problem != null) return problem;
    final identity = desk.expandHome(_identity.text.trim());
    const public = 'Choose the private ssh key here; this is a public key. The public key goes in the next field.';
    if (identity.endsWith('.pub')) return public;
    try {
      final file = File(identity);
      // Inspect only the public-key prefix, never the private key's contents.
      final input = file.openSync();
      try {
        if (String.fromCharCodes(input.readSync(4)) == 'ssh-') return public;
      } finally {
        input.closeSync();
      }
    } on FileSystemException {
      return 'Cannot read the private ssh key file.';
    }
    return _fileProblem(_publicKey.text, 'Your public ssh key');
  }

  Widget _panel(List<Widget> children) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: [...children, if (_machineProblem != null) Text(_machineProblem!)],
  );

  List<WizardStep> get _steps => [
    WizardStep(
      title: 'Where it is rented',
      words:
          'Porelo rents a server from Scaleway Elastic Metal, or finds it again. '
          'Find the project id in the Scaleway console under Project, Settings. '
          'The provider key is the one porelo-host key set scaleway kept. '
          'The account is the OS user that will run your project on the server.',
      panel: (_) => _panel([
        _field(_scaleway, 'Scaleway project id', 'host-scaleway-project', namesHost: true),
        _field(_account, 'Account on the server', 'host-account', namesHost: true),
      ]),
      check: () => _required([_scaleway, _account], 'Give the Scaleway project id and the account on the server.'),
      summary: () => ['Scaleway project id: ${_scaleway.text}', 'Account on the server: ${_account.text}'],
    ),
    WizardStep(
      title: 'The drive',
      words:
          'Tresorit, the one drive available today. Choose its synced folder on this computer. '
          'When a folder is chosen, give the repository address and the public key used to sign commits.',
      panel: (_) => _panel([
        const Text('Its synced folder on this computer'),
        Row(
          children: [
            Flexible(child: Text(_folder ?? 'No folder chosen')),
            const SizedBox(width: Space.small),
            TextButton(
              key: const Key('host-folder'),
              onPressed: _running || _upStarted ? null : _chooseFolder,
              child: const Text('Choose…'),
            ),
          ],
        ),
        if (_folder == null) const Text('Supply the host files manually if no folder is chosen.'),
        _field(_tresor, "The tresor's name in Tresorit", 'host-tresor', namesHost: true),
        const Text(
          'The server signs in to Tresorit and syncs the tresor by this name; '
          'the folder is this computer’s copy, where the server’s files are written.',
        ),
        if (Platform.isWindows)
          const Text('The server setup files and saved VPN connection can be read only by your Windows user.'),
        if (_folder != null) ...[
          _field(_repository, 'Project repository address', 'host-repository', namesHost: true),
          _pathField(_signingKey, 'Public key for signing commits (.pub)', 'host-signing-key'),
          _field(_keyName, 'Optional vault entry name', 'host-key-name', namesHost: true),
          TextButton(
            onPressed: _running || _upStarted ? null : _addKey,
            child: const Text('Choose a file for this vault entry'),
          ),
          for (final key in _keys)
            Row(
              children: [
                Expanded(child: Text('${key.name}: ${key.basename}')),
                IconButton(
                  onPressed: _running || _upStarted ? null : () => setState(() => _keys.remove(key)),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove this file',
                ),
              ],
            ),
        ],
      ]),
      check: () =>
          _required([_tresor], 'Give the tresor name from Tresorit.') ??
          (_folder == null
              ? null
              : _required([_repository, _signingKey], 'Give the repository address and its signing key.') ??
                    _driveFilesProblem),
      summary: () => [
        'Tresorit tresor: ${_tresor.text}',
        'Synced folder on this computer: ${_folder ?? 'not chosen; supply the host files manually'}',
        if (_folder != null) ...[
          'Project repository address: ${_repository.text}',
          'Public signing key: ${_signingKey.text}',
          for (final key in _keys) 'Vault entry ${key.name}: ${key.basename}',
        ],
      ],
    ),
    WizardStep(
      title: 'Your ssh keys',
      words:
          'The private key on this computer logs in to the server. '
          'Its public key is installed on the server to let that login in. '
          'Choose the private key first, then its public .pub file.',
      panel: (_) => _panel([
        _pathField(_identity, 'Your private ssh key', 'host-identity'),
        _pathField(_publicKey, 'Your public ssh key', 'host-public-key'),
      ]),
      check: () => _keysProblem,
      summary: () => ['Private ssh key: ${_identity.text}', 'Public ssh key: ${_publicKey.text}'],
    ),
    WizardStep(
      title: 'The setup file',
      words:
          'The server setup collection (.tar.gz) tells the host how to install Porelo and prepare the project. '
          'Choose the collection file on this computer.',
      panel: (_) => _panel([_pathField(_collection, 'Server setup file (.tar.gz)', 'host-collection')]),
      check: () =>
          _required([_collection], 'Choose the server setup file.') ??
          _fileProblem(_collection.text, 'The server setup file'),
      summary: () => ['Server setup file: ${_collection.text}'],
    ),
  ];

  WizardActionState get _actionState {
    if (_running) return WizardActionState.running;
    if (_machineProblem != null) return WizardActionState.refused;
    return switch (_session?.state) {
      HostRunState.done => WizardActionState.done,
      HostRunState.waiting => WizardActionState.waiting,
      HostRunState.running => WizardActionState.running,
      _ => WizardActionState.refused,
    };
  }

  @override
  Widget build(BuildContext context) => widget.takeDownOnly
      ? _takeDownDialog(context)
      : Wizard(
          title: 'Put the project ${widget.project} on a server',
          steps: _steps,
          action: 'Put it on a server',
          actionKey: const Key('host-up'),
          scrollController: _scroll,
          actionSteps: [
            WizardActionStep(
              title: _takingDown ? 'Taking it off the server' : 'Putting it on a server',
              words:
                  'The host reports its steps below. At a stop, complete what it asks in its terminal. '
                  'Only the host can confirm that setup is done.',
              panel: _progress,
              run: _up,
              state: () => _actionState,
            ),
          ],
          actions: (_, run) => OutlinedButton(
            key: const Key('host-down'),
            onPressed: _running || !_complete ? null : () => run(_down),
            child: const Text('Take it off the server'),
          ),
        );

  Widget _takeDownDialog(BuildContext context) {
    final started = _session != null;
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        key: const Key('host-take-down'),
        title: Text('Take the server for ${widget.project} down?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This ends the tasks for project ${widget.project} and its room, and removes its files on the host. '
                  'The host reports whether its files were copied and the server was given back.',
                ),
                if (started) _progress(context),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('host-close'),
            onPressed: _running ? null : () => Navigator.pop(context),
            child: Text(started ? 'Close' : 'Cancel'),
          ),
          if (!started || _actionState != WizardActionState.done)
            FilledButton(
              key: const Key('host-down'),
              onPressed: _running || widget.settings?.hostUp(widget.project) == null ? null : _down,
              child: Text(started ? 'Try taking it down again' : 'Take this server down'),
            ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final session = _session;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (session != null) ...<Widget>[
          for (final step in session.steps) _stepRow(step),
          if (session.state == HostRunState.waiting)
            if (_takingDown)
              const Text('The host has not completed teardown. Your machines have been kept.')
            else
              _askForTheStop(session.needs),
          if (session.said.isNotEmpty && session.said != session.fix) Text(session.said),
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
      Expanded(child: Text([step.step, if (step.words?.isNotEmpty == true) step.words!].join(': '))),
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
