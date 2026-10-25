import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;

import '../app/desk.dart';
import '../app/fleet_backend.dart';
import '../client/models.dart';
import '../app/commands.dart';
import '../app/host_session.dart';
import '../app/host_runs.dart';
import '../app/host_vpn.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import '../app/session.dart';
import 'wizard.dart';
import 'tokens.dart';
import 'host_stop_dialog.dart';
import 'dialog_scroll.dart';
import 'host_vpn_dialog.dart';
import 'host_key_dialog.dart';

/// Confirms teardown and shows the host's steps using only the kept setup arguments.
Future<void> openHostTakeDownDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  required Settings settings,
  StartHostCommand? start,
  HostRuns? hostRuns,
  OpenTerminal? openTerminal,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => HostDialog(
    project: project,
    machines: machines,
    settings: settings,
    start: start,
    hostRuns: hostRuns,
    openTerminal: openTerminal,
    existingRun: switch (hostRuns?.of(project)) {
      final run? when !run.ready && !run.givenBack => run,
      _ => null,
    },
    takeDownOnly: true,
  ),
);

/// Puts [project] on a server, or takes it off again, by the `porelo-host` shipped beside this
/// interface, showing each step as it says it and asking at its one stop.
Future<void> openHostDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  StartHostCommand? start,
  required Settings settings,
  required HostRuns hostRuns,
  required FleetBackend backend,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => HostDialog(
    project: project,
    machines: machines,
    backend: backend,
    start: start,
    settings: settings,
    hostRuns: hostRuns,
    onStarted: () => Navigator.pop(context),
  ),
);

/// Opens the setup protocol after the wizard has handed off its run.
Future<void> openHostRunDialog(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns hostRuns,
  required Machines machines,
  Settings? settings,
  OpenTerminal? openTerminal,
}) => showDialog<void>(
  context: context,
  builder: (_) => HostDialog(
    project: run.project,
    machines: machines,
    settings: settings,
    hostRuns: hostRuns,
    existingRun: run,
    openTerminal: openTerminal,
  ),
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
    this.checkKey,
    this.hostRuns,
    this.hostFiles,
    this.backend,
    this.existingRun,
    this.onStarted,
    this.openTerminal,
    this.environment,
    this.settings,
    this.secretStore,
    this.pickFolder,
    this.pickFile,
    this.takeDownOnly = false,
    this.debug = kDebugMode,
    super.key,
  }) : assert(takeDownOnly || hostRuns != null);

  /// The project to put on a server.
  final String project;

  /// The selected project's machine, captured when the wizard opens.
  final FleetBackend? backend;

  /// File work, injectable so widget tests control preparation and export completion.
  final HostFiles Function(SecretStore store)? hostFiles;

  /// The frame's owner, required for setup and retained after the wizard closes.
  final HostRuns? hostRuns;

  /// A run opened from Machines or Needs you, without asking setup questions again.
  final HostPreparation? existingRun;

  /// Closes the app's setup wizard as soon as ownership has transferred.
  final VoidCallback? onStarted;

  /// Starts the command; the shipped one when null.
  final StartHostCommand? start;

  /// Starts the non-interactive key check; replaceable without running a provider request in tests.
  final StartHostCommand? checkKey;

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

  /// System pickers, replaceable without platform calls in widget tests; each starts where the last one ended.
  final Future<String?> Function(String? initialDirectory)? pickFolder;

  /// Chooses a path file without opening a platform dialog in tests, starting where the last pick ended.
  final Future<String?> Function(String? initialDirectory)? pickFile;

  /// Shows the machine's teardown confirmation and progress without asking setup questions.
  final bool takeDownOnly;

  /// Enables the test collection step; defaults to the build's debug mode.
  final bool debug;

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
  final _collectionSha256 = TextEditingController();
  final _signingKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _keyName = TextEditingController();
  final _keys = <HostKeyFile>[];
  final _scroll = ScrollController();
  String? _folder;
  String? _keyProblem;
  bool _checkingKey = false;

  // Where the next picker starts: the folder of the last file or folder chosen in this dialog.
  String? _lastFolder;
  HostTunnel? _tunnel;
  bool _preparing = false;
  Followed? _followed;
  List<int>? _bundle;
  String? _sourceProblem = 'The drive: reading the project’s verified source from its machine.';

  HostSession? _session;
  HostPreparation? _hostRun;
  bool _transferred = false;
  bool _sessionActive = false;
  // A run already finished when its protocol is opened is closed only by the person.
  bool _closingAfterVpn = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.hostRuns?.addListener(_sessionChanged);
    _folder = widget.settings?.tresorFolder(widget.project);
    if (_folder != null) _tresor.text = path.basename(path.normalize(_folder!));
    final kept = widget.existingRun?.record ?? widget.settings?.hostUp(widget.project);
    if (kept != null) {
      _scaleway.text = kept.scalewayProject;
      _account.text = kept.account;
      _tresor.text = kept.tresor;
      _folder = kept.folder;
      _signingKey.text = kept.signingKey;
      _identity.text = kept.identity;
      _publicKey.text = kept.publicKey;
      _collection.text = kept.collection;
      _collectionSha256.text = kept.collectionSha256;
    }
    if (widget.existingRun == null && !widget.takeDownOnly) unawaited(_readSource());
    final run = widget.existingRun;
    if (run != null) {
      _hostRun = run;
      _closingAfterVpn = run.ready;
      _session = run.session;
      _session!.addListener(_sessionChanged);
      _transferred = true;
      _upStarted = true;
      _tunnel = run.tunnel;
    }
  }

  Future<void> _readSource() async {
    final backend = widget.backend ?? widget.machines.fleet.backend;
    try {
      final records = await backend.following();
      final source = records.where((record) => record.name == widget.project).singleOrNull;
      if (!mounted) return;
      setState(() {
        _followed = source;
        _sourceProblem = source == null || source.commit.isEmpty || source.unverified
            ? 'The drive: this project has no verified commit to put on a server.'
            : source.url.trim().isEmpty
            ? 'The drive: the machine supplied no repository address for this project.'
            : null;
      });
    } on Exception {
      if (mounted) {
        setState(() => _sourceProblem = 'The drive: the project’s verified source could not be read from its machine.');
      }
    }
  }

  Future<bool> _checkBundle() async {
    if (_sourceProblem != null) return false;
    if (_folder == null || _bundle != null) return true;
    setState(() {
      _preparing = true;
      _machineProblem = null;
    });
    try {
      final source = _followed!;
      await _withFiles((files) async {
        _bundle = await files.createBundle(project: widget.project, url: source.url, commit: source.commit);
      });
      return mounted;
    } on HostFilesRefused catch (error) {
      if (mounted) setState(() => _machineProblem = error.message);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _machineProblem = _preparationProblem(error));
    } on SecretStoreFailed {
      if (mounted) setState(() => _machineProblem = 'The system secret store could not be opened.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    return false;
  }

  bool _upStarted = false;
  bool _takingDown = false;
  bool _finishingDown = false;
  bool _givenBack = false;
  bool _vpnDownConfirmed = false;
  Machine? _givenBackMachine;
  String? _vpnProblem;
  String? _machineProblem;

  static String _home(String relativePath) => desk.expandHome('~/$relativePath');

  @override
  void dispose() {
    for (final field in <TextEditingController>[
      _signingKey,
      _keyName,
      _scaleway,
      _tresor,
      _account,
      _publicKey,
      _identity,
      _collection,
      _collectionSha256,
    ]) {
      field.dispose();
    }
    widget.hostRuns?.removeListener(_sessionChanged);
    _ticker?.cancel();
    _session?.removeListener(_sessionChanged);
    // A confirmed leave must not dispose a notifier while its process is still answering.
    if (!_sessionActive && !_transferred) _session?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (_givenBack && widget.hostRuns?.vpnLinkUp == false) {
      _vpnDownConfirmed = true;
      _vpnProblem = null;
    }
    if (_hostRun?.ready == true && widget.existingRun != null && !_closingAfterVpn) {
      _closingAfterVpn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    setState(() {});
  }

  void _expandPaths() {
    final fields = [_publicKey, _identity, if (widget.debug) _collection, _signingKey];
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
    repository: '',
    signingKey: _signingKey.text.trim(),
    identity: _identity.text.trim(),
    publicKey: _publicKey.text.trim(),
    collection: widget.debug ? _collection.text.trim() : '',
    collectionSha256: widget.debug ? _collectionSha256.text.trim() : '',
    vpnPeerPublicKey: _tunnel?.peerPublicKey ?? '',
    vpnPeerAddress: _tunnel == null ? '' : '10.73.0.2/32',
    vpnHostPublicKey: _tunnel?.hostPublicKey ?? '',
  );

  HostSession _newSession({HostUpRecord? record}) {
    if (!_transferred) _session?.dispose();
    final session = HostSession(
      executable: poreloHost(environment: widget.environment),
      arguments: hostArguments(record ?? _record(), widget.project, debug: widget.debug),
      start: widget.start,
    )..addListener(_sessionChanged);
    return _session = session;
  }

  bool get _complete => <TextEditingController>[
    _scaleway, _tresor, _account, _publicKey, _identity,
    if (widget.debug) ...[_collection, _collectionSha256], //
  ].every((field) => field.text.trim().isNotEmpty);

  bool get _running =>
      _preparing || _finishingDown || _hostRun?.running == true || _session?.state == HostRunState.running;

  Future<void> _withFiles(Future<void> Function(HostFiles) use) =>
      withHostFiles(use, secretStore: widget.secretStore, hostFiles: widget.hostFiles);

  Future<void> _chooseFolder() async {
    final folder = await (widget.pickFolder?.call(_lastFolder) ?? getDirectoryPath(initialDirectory: _lastFolder));
    if (folder == null || !mounted) return;
    _lastFolder = folder;
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

  Future<String?> _pickFile() async {
    final file = widget.pickFile == null
        ? (await openFile(initialDirectory: _lastFolder))?.path
        : await widget.pickFile!(_lastFolder);
    if (file != null) _lastFolder = path.dirname(desk.expandHome(file.trim()));
    return file;
  }

  Future<void> _chooseFile(TextEditingController field) async {
    final file = await _pickFile();
    if (file == null || !mounted) return;
    String? expanded(String value) {
      try {
        return desk.expandHome(value.trim());
      } on FormatException {
        return null;
      }
    }

    final previous = expanded(_identity.text);
    final selected = expanded(file);
    final nextDefault = selected == null ? null : '$selected.pub';
    final prefill =
        field == _identity &&
        nextDefault != null &&
        (_publicKey.text.trim().isEmpty || previous != null && expanded(_publicKey.text) == '$previous.pub') &&
        File(nextDefault).existsSync();
    setState(() {
      field.text = file;
      if (prefill) _publicKey.text = nextDefault;
    });
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
        if (!await _checkBundle()) return;
        setState(() => _preparing = true);
        await _withFiles((files) async {
          if (_folder != null) {
            await files.publishBundle(project: widget.project, folder: _folder!, bytes: _bundle!);
          }
          _tunnel = await files.prepare(
            project: widget.project,
            folder: _folder,
            url: HostFiles.bundleUrl(widget.project),
            signingKey: File(_signingKey.text.trim()),
            keys: _keys,
          );
        });
        if (!mounted) return;
        final record = _record().withPreparation(DateTime.now().toUtc());
        await widget.settings?.rememberHostUp(widget.project, record);
        if (!mounted) return;
        _newSession(record: record);
        _upStarted = true;
      }
      if (_hostRun == null) {
        final owner = widget.hostRuns;
        if (owner == null) throw StateError('Host setup needs its HostRuns owner.');
        final run = owner.start(
          project: widget.project,
          session: _session!,
          record: widget.settings?.hostUp(widget.project) ?? _record(),
          tunnel: _tunnel,
          settings: widget.settings,
        );
        _hostRun = run;
        _transferred = true;
        widget.onStarted?.call();
        await run.finished;
      } else {
        await _runUp(_session!.up);
      }
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

  // Keep the rented host's identity so teardown cannot silently target a different host.
  Future<void> _down() async {
    if (_running) return;
    if (_givenBack) return _takeVpnDown();
    final kept = widget.settings?.hostUp(widget.project);
    if (widget.takeDownOnly && kept == null) return;
    setState(() => _takingDown = true);
    try {
      if (kept == null && !_upStarted) _expandPaths();
    } on FormatException catch (error) {
      setState(() => _machineProblem = error.message);
      return;
    }
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
    if (!hostGivenBack(session)) {
      if (mounted) setState(() => _machineProblem = 'The server give-back was not confirmed. Recovery has been kept.');
      return;
    }
    final owner = widget.hostRuns;
    if (mounted) setState(() => _finishingDown = true);
    try {
      if (owner != null) {
        await owner.confirmDown(widget.project, session);
      } else if (kept != null) {
        await widget.settings?.rememberHostUp(widget.project, kept.withPreparation(null));
      }
      final address = session.releasedAddress;
      if (address == null || address.isEmpty) {
        if (mounted) setState(() => _machineProblem = 'No host was found. Your machines have been kept.');
      } else {
        for (final machine in widget.machines.all) {
          if (machine.kind == 'host' && machine.host == '$account@$address') {
            await widget.machines.forget(machine);
          }
        }
      }
      _givenBack = true;
      _givenBackMachine = Machine(
        name: '${widget.project} server',
        kind: 'host',
        hostProject: widget.project,
        socketPath: '',
      );
      owner?.rememberVpnToTakeDown(_givenBackMachine!);
      if (mounted) await _takeVpnDown();
    } finally {
      if (mounted) setState(() => _finishingDown = false);
    }
  }

  Future<void> _takeVpnDown() async {
    final machine = _givenBackMachine;
    if (machine == null) return;
    setState(() => _finishingDown = true);
    final owner = widget.hostRuns;
    try {
      await openHostVpnDialog(
        context,
        machine: machine,
        settings: widget.settings ?? widget.machines.settings,
        up: false,
        open: widget.openTerminal,
        probeLink: owner?.probeVpnLink,
      );
      bool? linkUp;
      if (owner != null) {
        await owner.refreshVpns();
        linkUp = owner.vpnLinkUp;
      } else {
        try {
          linkUp = await probeHostVpnLink();
        } on HostFilesRefused {
          linkUp = null;
        }
      }
      if (mounted) {
        setState(() {
          _vpnDownConfirmed = linkUp == false;
          _vpnProblem = linkUp == false
              ? null
              : linkUp == true
              ? 'The server is given back; the VPN on this computer is still up'
              : 'The server is given back; the VPN on this computer could not be checked';
        });
      }
    } finally {
      if (mounted) setState(() => _finishingDown = false);
    }
  }

  Future<void> _runHost(Future<void> Function() run) async {
    _sessionActive = true;
    try {
      await run();
    } finally {
      _sessionActive = false;
      if (!mounted && !_transferred) _session?.dispose();
    }
  }

  Future<void> _runUp(Future<void> Function() run) async {
    _machineProblem = null;
    if (_hostRun case final preparation?) {
      await widget.hostRuns!.resume(preparation);
    } else {
      await _runHost(run);
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
      if (widget.debug) (value: _collection.text, label: 'Test collection (.tar.gz)', step: 'A test collection'),
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

  Future<bool> _checkScalewayKey() async {
    setState(() => _checkingKey = true);
    final answer = await checkHostScalewayKey(start: widget.checkKey, environment: widget.environment);
    if (!mounted) return false;
    setState(() {
      _checkingKey = false;
      _keyProblem = answer.code == 0 ? null : answer.message;
    });
    return answer.code == 0;
  }

  Future<void> _setScalewayKey() async {
    final accepted = await openHostKeyDialog(context, open: widget.openTerminal, environment: widget.environment);
    if (mounted && accepted) await _checkScalewayKey();
  }

  Widget _scalewayKeyAction() {
    final command = setScalewayKeyCommand(run: () => unawaited(_setScalewayKey()), checking: _checkingKey);
    return Tooltip(
      message: command.unavailable ?? 'Enter the secret key in a terminal on this computer.',
      child: TextButton(
        key: const Key('host-set-scaleway-key'),
        onPressed: command.available ? command.run : null,
        child: Text(command.label),
      ),
    );
  }

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
        if (_keyProblem != null) Text(_keyProblem!, key: const Key('host-scaleway-key-problem')),
        _scalewayKeyAction(),
      ]),
      check: () => _required([_scaleway, _account], 'Give the Scaleway project id and the account on the server.'),
      beforeNext: _checkScalewayKey,
      summary: () => ['Scaleway project id: ${_scaleway.text}', 'Account on the server: ${_account.text}'],
    ),
    WizardStep(
      title: 'The drive',
      words:
          'Tresorit, the one drive available today. Choose its synced folder on this computer. '
          'The project’s verified bundle is written into porelo-host in that folder. '
          'Give the public key used to sign its commits.',
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
          _sourceProblem ??
          (_folder == null
              ? null
              : _required([_signingKey], 'Give the public key used to sign commits.') ?? _driveFilesProblem),
      beforeNext: _checkBundle,
      summary: () => [
        'Tresorit tresor: ${_tresor.text}',
        'Synced folder on this computer: ${_folder ?? 'not chosen; supply the host files manually'}',
        if (_folder != null) ...[
          'Project bundle: porelo-host/${widget.project}.bundle',
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
      summary: () => [
        'Private ssh key: ${_identity.text}',
        'Public ssh key: ${_publicKey.text}',
        if (!widget.debug) 'Server setup collection: ${hostCollection.version}',
      ],
    ),
    if (widget.debug)
      WizardStep(
        title: 'A test collection',
        words:
            'Choose a test collection built from a clean clone and give its SHA-256. '
            'This replaces the collection carried with Porelo for this test.',
        panel: (_) => _panel([
          _pathField(_collection, 'Test collection (.tar.gz)', 'host-collection'),
          _field(_collectionSha256, 'Test collection SHA-256', 'host-collection-sha256', namesHost: true),
        ]),
        check: () =>
            _required([_collection, _collectionSha256], 'Choose the test collection and give its SHA-256.') ??
            (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(_collectionSha256.text.trim())
                ? 'Give the test collection SHA-256 as 64 hexadecimal digits.'
                : null) ??
            _fileProblem(_collection.text, 'The test collection'),
        summary: () => ['Test collection: ${_collection.text}', 'Test collection SHA-256: ${_collectionSha256.text}'],
      ),
  ];

  WizardActionState get _actionState {
    if (_running) return WizardActionState.running;
    if (_machineProblem != null || !_takingDown && _hostRun?.problem != null) return WizardActionState.refused;
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
      : widget.existingRun != null
      ? _runDialog(context)
      : Wizard(
          title: 'Put the project ${widget.project} on a server',
          reviewWords: 'A server for the project ${widget.project}. Check every answer before starting.',
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
            onPressed: _running || !_complete
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => _takeDownDialog(context, confirmationOnly: true),
                    );
                    if (confirmed == true && mounted) await run(_down);
                  },
            child: Text(_takingDown ? 'Try taking it down again' : 'Take this server down'),
          ),
        );

  Widget _runDialog(BuildContext context) => AlertDialog(
    key: const Key('host-protocol'),
    title: Text('${widget.project} server'),
    content: SizedBox(
      width: Sizes.dialogMedium,
      child: DialogScroll(child: _progress(context)),
    ),
    actions: [
      TextButton(key: const Key('host-close'), onPressed: () => Navigator.pop(context), child: const Text('Close')),
      if (_hostRun case final run? when run.awaitingVpn)
        Builder(
          builder: (_) {
            final command = setupHostVpnCommand(
              alreadyOpen: run.vpnOpen,
              run: () => unawaited(
                openPreparationVpn(
                  context,
                  run: run,
                  runs: widget.hostRuns!,
                  settings: widget.settings!,
                  open: widget.openTerminal,
                  secretStore: widget.secretStore,
                  hostFiles: widget.hostFiles,
                  environment: widget.environment,
                ),
              ),
            );
            return TextButton(
              key: const Key('host-vpn-up'),
              onPressed: command.available ? command.run : null,
              child: Text(command.label),
            );
          },
        )
      else if (_hostRun case final run? when !run.ready && !run.givenBack && !run.running && !run.waiting)
        Builder(
          builder: (_) {
            final command = resumeHostPreparationCommand(
              run: run,
              resume: () => unawaited(widget.hostRuns!.resume(run)),
            );
            return Tooltip(
              message: command.unavailable ?? command.label,
              child: TextButton(
                key: Key(run.interrupted ? 'host-go-on' : 'host-retry'),
                onPressed: command.available ? command.run : null,
                child: Text(command.label),
              ),
            );
          },
        ),
    ],
  );

  Widget _takeDownDialog(BuildContext context, {bool confirmationOnly = false}) {
    final started = !confirmationOnly && _takingDown && _session != null;
    final colors = Theme.of(context).colorScheme;
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
                  'The server for project ${widget.project} is given back to Scaleway and deleted. '
                  'Nothing is billed afterwards. '
                  'The vault on the server and the room’s history are lost. '
                  'The files in the tresor are kept.',
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
          if (_givenBack && !_vpnDownConfirmed)
            Builder(
              builder: (context) {
                final command = takeGivenBackVpnDownCommand(
                  home: Home.openedView,
                  run: () => unawaited(_takeVpnDown()),
                  unavailable: _running ? 'the VPN is still being checked' : null,
                );
                return Tooltip(
                  message: command.unavailable ?? 'Take WireGuard down on this computer.',
                  child: TextButton(onPressed: command.available ? command.run : null, child: Text(command.label)),
                );
              },
            ),
          if (!_givenBack && (!started || _actionState != WizardActionState.done))
            FilledButton(
              key: Key(confirmationOnly ? 'host-confirm-down' : 'host-down'),
              style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
              onPressed: _running || widget.takeDownOnly && widget.settings?.hostUp(widget.project) == null
                  ? null
                  : confirmationOnly
                  ? () => Navigator.pop(context, true)
                  : _down,
              child: const Text('Give the server back'),
            ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final session = _session;
    if (session?.state == HostRunState.running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (session != null) ...<Widget>[
          for (final record in session.history) _stepRow(record),
          if (_hostRun?.interrupted == true && _hostRun?.givenBack != true) ...[
            if (session.interruptionText case final text?) Text(text),
            const Text('Nothing runs now. Go on continues from where it stopped.'),
          ],
          if (session.state == HostRunState.running)
            if (session.timeLeftText case final text?) Text(text),
          if (session.state == HostRunState.busy) Text('Setup of ${widget.project} is still running from before.'),
          if (session.state == HostRunState.waiting)
            if (_takingDown)
              const Text('The host has not completed teardown. Your machines have been kept.')
            else
              _askForTheStop(),
          if (session.said.isNotEmpty && session.said != session.fix) Text(session.said),
          if (session.fix != null && !session.history.any((record) => record.step.fix == session.fix))
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                session.fix!,
                key: const Key('host-fix'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (session.state == HostRunState.done &&
              (_takingDown ? _vpnDownConfirmed : _hostRun == null || _hostRun!.ready))
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(
                !_takingDown && _hostRun?.ready == true
                    ? 'Ready: ${widget.project} server is in your machines'
                    : 'Done.',
                key: const Key('host-done'),
              ),
            ),
        ],
        if (!_takingDown)
          if (_hostRun?.problem case final problem?) Text(problem),
        if (_machineProblem != null) Text(_machineProblem!),
        if (_vpnProblem != null) Text(_vpnProblem!),
        if (session != null)
          ExpansionTile(
            key: const Key('host-full-protocol'),
            title: const Text('Full protocol'),
            children: [SelectableText(session.protocol.join('\n'))],
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

  Widget _stepRow(HostStepRecord record) => Row(
    key: Key('host-step-${record.step.step}'),
    children: <Widget>[
      Icon(switch (record.step.state) {
        StepState.started => Icons.pending_outlined,
        StepState.done => Icons.check,
        StepState.refused => Icons.error_outline,
        StepState.waiting => Icons.person_outline,
        StepState.plan => Icons.list_alt_outlined,
      }, size: Sizes.mark),
      const SizedBox(width: Space.small),
      Expanded(
        child: Text(
          _session!.stepLine(record),
          key: record.step.fix != null && record.step.fix == _session!.fix ? const Key('host-fix') : null,
        ),
      ),
    ],
  );

  Widget _askForTheStop() => KeyedSubtree(
    key: const Key('host-stop'),
    child: FilledButton(
      key: const Key('host-complete-setup'),
      onPressed: _running || _hostRun == null
          ? null
          : () => openHostStopDialog(
              context,
              run: _hostRun!,
              hostRuns: widget.hostRuns!,
              machines: widget.machines,
              settings: widget.settings,
              openTerminal: widget.openTerminal,
            ),
      child: const Text('Complete setup on the host'),
    ),
  );
}
