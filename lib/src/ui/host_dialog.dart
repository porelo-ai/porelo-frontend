import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:path/path.dart' as path;

import '../app/desk.dart';
import '../app/fleet_backend.dart';
import '../client/models.dart';
import '../app/commands.dart';
import '../app/host_session.dart';
import '../app/host_protocol.dart';
import '../app/host_runs.dart';
import '../app/host_vpn.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import '../app/session.dart';
import 'wizard.dart';
import 'tokens.dart';
import 'unlock_terminal.dart';
import 'host_stop_dialog.dart';
import 'command_to_copy.dart';
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
  bool? linux,
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
    linux: linux,
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
    this.linux,
    this.environment,
    this.settings,
    this.secretStore,
    this.pickFile,
    this.openSecretsFile,
    this.setupFolder,
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

  /// Overrides the local VPN platform choice for tests.
  final bool? linux;

  /// Overrides command selection for a development walk.
  final Map<String, String>? environment;

  /// The fleet to add the completed host to and remove it from.
  final Machines machines;

  /// The interface's project-specific folder choices.
  final Settings? settings;

  /// An injected store for tests; otherwise opened and closed for each operation.
  final SecretStore? secretStore;

  /// Chooses a path file without opening a platform dialog in tests, starting where the last pick ended.
  final Future<String?> Function(String? initialDirectory)? pickFile;

  /// Opens the person's secrets file in a terminal on this desktop and answers the host key's public half; the
  /// terminal with `keepassxc-cli` when null, a stand-in in tests. It refuses with [HostFilesRefused].
  final Future<String> Function({
    required String file,
    required String project,
    String? migrateKeyFrom,
    Map<String, String> keys,
  })?
  openSecretsFile;

  /// The interface's own folder for the host's `machine.yml` and bundle, which `up` uploads; the configuration
  /// folder's `hosts/<project>` when null, a scratch folder in tests.
  final String? setupFolder;

  /// Shows the machine's teardown confirmation and progress without asking setup questions.
  final bool takeDownOnly;

  /// Enables the test collection step; defaults to the build's debug mode.
  final bool debug;

  @override
  State<HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends State<HostDialog> {
  final _scaleway = TextEditingController();
  final _account = TextEditingController(text: 'porelo');
  final _publicKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _identity = TextEditingController(text: _home('.ssh/id_ed25519'));
  final _collection = TextEditingController();
  final _collectionSha256 = TextEditingController();
  final _signingKey = TextEditingController(text: _home('.ssh/id_ed25519.pub'));
  final _keyName = TextEditingController();
  final _secrets = TextEditingController(text: _home('Porelo/secrets.kdbx'));

  /// The host key's public half, once the secrets file was opened for this file; dropped when the file changes.
  String? _hostPublicKey;
  ({String file, String drive, String keys})? _hostPublicKeyFor;
  bool _openingSecrets = false;
  String? _secretsAnswer;
  final _keys = <HostKeyFile>[];
  final _scroll = ScrollController();
  final _protocolScroll = ScrollController();
  final _protocolViewport = GlobalKey();
  final _protocolKeys = Expando<GlobalKey>();
  List<GlobalKey> _protocolRows = [];
  bool _protocolUpdateScheduled = false;
  // A drive's synced folder remembered from setups before the drive left them: read only for a host key it may still
  // hold, which the secrets file takes over.
  String? _folder;
  String? _keyProblem;
  bool _checkingKey = false;

  // Where the next picker starts: the folder of the last file or folder chosen in this dialog.
  String? _lastFolder;
  HostTunnel? _tunnel;
  bool _preparing = false;
  Followed? _followed;
  List<int>? _bundle;
  // The signing key the bundle's commit was checked against: another key checks it again.
  String? _bundleKey;
  // The key the newest check is about, and that check's number: an older check's answer is dropped.
  String? _signingCheckKey;
  int _signingChecks = 0;
  // Why the key in the field did not pass; it goes the moment the field changes.
  String? _signingRefusal;
  // What the field held when it was last looked at, so a rebuild with the same text asks nothing again.
  String? _signingKeyShown;
  // Whether the public ssh key belongs to the private one: the two paths the answer is about, and the answer;
  // null when ssh-keygen cannot say, which refuses nothing.
  String? _pairAnsweredFor;
  bool? _pairBelongs;
  String? _pairRefusal;
  String? _identityShown;
  String? _publicKeyShown;
  String? _sourceProblem = 'The drive: reading the project’s verified source from its machine.';

  HostSession? _session;
  HostPreparation? _hostRun;
  bool _transferred = false;
  bool _sessionActive = false;
  // A run already finished when its protocol is opened is closed only by the person.
  bool _closingAfterVpn = false;
  Timer? _ticker;

  /// The earlier attempt chosen to be shown; null for the current one.
  HostAttemptRecord? _shownAttempt;

  @override
  void initState() {
    super.initState();
    widget.hostRuns?.addListener(_sessionChanged);
    _folder = widget.settings?.tresorFolder(widget.project);
    if (widget.settings?.secretsFile case final file?) _secrets.text = file;
    final kept = widget.existingRun?.record ?? widget.settings?.hostUp(widget.project);
    // A record from host files given by hand kept no signing key: the field keeps its default or a pinned key.
    _signingKeyKept = kept != null && kept.signingKey.isNotEmpty;
    if (kept != null) {
      _scaleway.text = kept.scalewayProject;
      _account.text = kept.account;
      _folder = kept.folder ?? _folder;
      if (kept.signingKey.isNotEmpty) _signingKey.text = kept.signingKey;
      _identity.text = kept.identity;
      _publicKey.text = kept.publicKey;
      _collection.text = kept.collection;
      _collectionSha256.text = kept.collectionSha256;
    }
    _signingKeyShown = _expanded(_signingKey.text);
    _signingKey.addListener(_signingKeyChanged);
    _identityShown = _expanded(_identity.text);
    _publicKeyShown = _expanded(_publicKey.text);
    _identity.addListener(_identityChanged);
    _publicKey.addListener(_publicKeyChanged);
    if (widget.existingRun == null && !widget.takeDownOnly) {
      // After the first frame: the check's answer changes state, which initState may not.
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkPairWhenReady());
      unawaited(_readSource());
    }
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
        if (source != null && !_signingKeyKept) _preferPinnedKey(source.signers);
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

  /// Opens the signing key field on a public key the project's machine pins, not on the ssh key by default.
  ///
  /// Read at once: ~/.ssh holds a few small files, as `_fileProblem` reads the chosen ones.
  void _preferPinnedKey(List<String> pinned) {
    if (pinned.isEmpty) return;
    try {
      final keys =
          Directory(_home('.ssh')).listSync().whereType<File>().where((file) => file.path.endsWith('.pub')).toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final key in keys) {
        if (pinned.contains(_fingerprint(key.path))) {
          _signingKey.text = key.path;
          return;
        }
      }
    } on FileSystemException {
      // No ~/.ssh to look in: the field stays as it is.
    }
  }

  static String? _fingerprint(String file) {
    try {
      final expanded = desk.expandHome(file.trim());
      // Only a public key is read whole: never a private key, a pipe or a device.
      if (!_startsAsPublicKey(expanded)) return null;
      return HostFiles.signingFingerprint(File(expanded).readAsStringSync());
    } on HostFilesRefused {
      return null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The signing key as a full path, or null while what is typed cannot be one.
  String? get _signingKeyPath {
    try {
      return desk.expandHome(_signingKey.text.trim());
    } on FormatException {
      return null;
    }
  }

  /// Drops the answer about the key the field held before and asks about the one it holds now.
  void _signingKeyChanged() {
    final typed = _expanded(_signingKey.text);
    if (typed == _signingKeyShown) return;
    _signingKeyShown = typed;
    // Rebuilt in any case: a check mark is drawn for the key in the field, which a text set from code changes too.
    if (mounted) setState(() => _signingRefusal = null);
    _checkSigningKeyWhenReady();
  }

  /// Checks the signing key at once, when it reads as a public key and the drive and the source are there.
  void _checkSigningKeyWhenReady() {
    if (!mounted || _followed == null || _sourceProblem != null) return;
    final key = _signingKeyPath;
    if (key == null || _fingerprint(key) == null || (_bundle != null && _bundleKey == key)) return;
    unawaited(_checkSigningKey(key));
  }

  Future<bool> _checkBundle() async {
    if (_sourceProblem != null) return false;
    // Expanded, so the same key written as ~/ before the action and in full after it is not checked twice.
    final key = desk.expandHome(_signingKey.text.trim());
    if (_bundle != null && _bundleKey == key) {
      // The field's own check passed for this key; what an earlier Next said no longer stands.
      setState(() => _machineProblem = null);
      return true;
    }
    return _checkSigningKey(key, forNext: true);
  }

  /// Checks [key] against the verified commit; only a check [forNext] holds the dialog and speaks for the step.
  Future<bool> _checkSigningKey(String key, {bool forNext = false}) async {
    final check = ++_signingChecks;
    _signingCheckKey = key;
    // An answer about a key the field no longer holds is dropped, never shown. Two checks of the same key
    // answer alike, so either may.
    bool stillAsked() => mounted && _signingKeyPath == key;
    setState(() {
      if (forNext) {
        _preparing = true;
        _machineProblem = null;
      }
      _signingRefusal = null;
    });
    try {
      final source = _followed!;
      List<int>? bundle;
      await _withFiles((files) async {
        bundle = await files.createBundle(
          project: widget.project,
          url: source.url,
          commit: source.commit,
          signingKey: File(key),
        );
      });
      if (!stillAsked()) return false;
      setState(() {
        _bundle = bundle;
        _bundleKey = key;
      });
      return true;
    } on HostFilesRefused catch (error) {
      final chosen = _fingerprint(key);
      final swapped = error.message.contains(', not by ') && chosen != null && chosen == _fingerprint(_publicKey.text);
      if (stillAsked()) {
        setState(
          () => _signingRefusal = swapped
              ? '${error.message} It is also your public ssh key for signing in to the server: '
                    'the two key fields may be swapped.'
              : error.message,
        );
      }
    } on FileSystemException catch (error) {
      // What only Next can act on is said by Next; a check of the field alone says it at the field.
      if (stillAsked()) {
        setState(
          () => forNext ? _machineProblem = _preparationProblem(error) : _signingRefusal = _preparationProblem(error),
        );
      }
    } on SecretStoreFailed {
      const problem = 'The system secret store could not be opened.';
      if (stillAsked()) setState(() => forNext ? _machineProblem = problem : _signingRefusal = problem);
    } finally {
      // Next's hold ends with Next's own check, even when a newer check of the field runs on.
      if (mounted) {
        setState(() {
          if (forNext) _preparing = false;
          if (_signingChecks == check) _signingCheckKey = null;
        });
      }
    }
    return false;
  }

  /// What the signing key field says of the key in it: being checked, signed the commit, or refused.
  Widget? _signingKeyMark(BuildContext context) {
    final key = _signingKeyPath;
    return _mark(
      context,
      'host-signing-key',
      refused: _signingRefusal != null,
      passed: key != null && _bundle != null && _bundleKey == key,
      checking: key != null && _signingCheckKey == key,
      passedLabel: 'This key signed the verified commit',
      refusedLabel: 'This key did not sign the verified commit',
    );
  }

  /// What the public ssh key field says of the pair: being checked, belonging together, or refused.
  Widget? _publicKeyMark(BuildContext context) {
    final pair = _pairPaths;
    return _mark(
      context,
      'host-public-key',
      refused: _pairRefusal != null,
      passed: pair != null && _pairAnsweredFor == pair && _pairBelongs == true,
      checking: false,
      passedLabel: 'This public key belongs to the private key',
      refusedLabel: 'This public key does not belong to the private key',
    );
  }

  /// A checked field's mark: an error icon, a check mark, or an hourglass while it is checked; none otherwise.
  Widget? _mark(
    BuildContext context,
    String field, {
    required bool refused,
    required bool passed,
    required bool checking,
    required String passedLabel,
    required String refusedLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, suffix, colour, label) = refused
        ? (Icons.error_outline, 'refused', scheme.error, refusedLabel)
        : passed
        ? (Icons.check_circle_outline, 'ok', scheme.primary, passedLabel)
        : checking
        ? (Icons.hourglass_empty, 'checking', scheme.onSurfaceVariant, 'Being checked')
        : (null, '', null, '');
    if (icon == null) return null;
    return Icon(icon, key: Key('$field-$suffix'), size: Sizes.mark, color: colour, semanticLabel: label);
  }

  /// The two key paths in full, one per line, or null while either cannot be read as a path.
  String? get _pairPaths {
    try {
      return '${desk.expandHome(_identity.text.trim())}\n${desk.expandHome(_publicKey.text.trim())}';
    } on FormatException {
      return null;
    }
  }

  /// [text] as a full path, so a path and its `~/` form, as the start writes it out, count as one.
  static String _expanded(String text) {
    try {
      return desk.expandHome(text.trim());
    } on FormatException {
      return text.trim();
    }
  }

  /// Whether [file] names a Windows device, which reading would wait on rather than read.
  static bool _namesADevice(String file) =>
      desk.isWindows &&
      RegExp(r'^(CON|PRN|AUX|NUL|CONIN\$|CONOUT\$|COM[1-9]|LPT[1-9])$')
          .hasMatch(path.windows.basename(file).split('.').first.trimRight().toUpperCase());

  /// Whether [file] begins as a public key does; only those four bytes are read, never a private key's contents.
  static bool _startsAsPublicKey(String file) {
    // A pipe or a device would hold the read forever.
    if (_namesADevice(file) || FileSystemEntity.typeSync(file) != FileSystemEntityType.file) return false;
    final input = File(file).openSync();
    try {
      return String.fromCharCodes(input.readSync(4)) == 'ssh-';
    } finally {
      input.closeSync();
    }
  }

  /// Fills the public key with the private key's own `.pub` when there is one, over whatever it held.
  void _identityChanged() {
    final private = _expanded(_identity.text);
    if (private == _identityShown) return;
    _identityShown = private;
    final companion = '$private.pub';
    if (private.isNotEmpty &&
        !private.endsWith('.pub') &&
        !_namesADevice(private) &&
        File(companion).existsSync() &&
        companion != _expanded(_publicKey.text)) {
      // Changing the public key asks about the pair again.
      _publicKey.text = companion;
    } else {
      _pairChanged();
    }
  }

  void _publicKeyChanged() {
    final public = _expanded(_publicKey.text);
    if (public == _publicKeyShown) return;
    _publicKeyShown = public;
    _pairChanged();
  }

  /// Drops the answer about the pair the fields held before and asks about the one they hold now.
  void _pairChanged() {
    // Rebuilt in any case: a check mark is drawn for the pair in the fields, which a text set from code changes too.
    if (mounted) setState(() => _pairRefusal = null);
    _checkPairWhenReady();
  }

  void _checkPairWhenReady() {
    final asked = _pairToCheck;
    if (mounted && asked != null) _checkPair(asked);
  }

  /// The pair as it stands when it can be asked about: a private key that is a regular file and no public key, and
  /// a public key that reads as one. Null otherwise, which refuses nothing.
  ({String pair, String private, String public})? get _pairToCheck {
    final pair = _pairPaths;
    if (pair == null) return null;
    final [private, publicPath] = pair.split('\n');
    try {
      // A pipe or a device would hold the answer forever, and the answer is waited for.
      if (private.endsWith('.pub') || _namesADevice(private)) return null;
      if (FileSystemEntity.typeSync(private) != FileSystemEntityType.file || _startsAsPublicKey(private)) return null;
    } on FileSystemException {
      return null;
    }
    final public = _fingerprint(publicPath);
    return public == null ? null : (pair: pair, private: private, public: public);
  }

  /// Next asks about the pair itself, as it stands when Next is pressed.
  Future<bool> _checkPairForNext() async {
    final asked = _pairToCheck;
    return asked == null || _checkPair(asked) != false;
  }

  /// Asks ssh-keygen, in a process of its own, for the private key's fingerprint, which it reads without the
  /// passphrase, so the private key never enters this program. It is asked through a link alone in a private
  /// folder: beside the key, ssh-keygen reads the key's `.pub` instead, and would compare that with itself.
  /// Waited for, since it answers in milliseconds and asks nothing; so no answer can come late or about another pair.
  /// True when the two belong together, false when not, null when ssh-keygen cannot say.
  bool? _checkPair(({String pair, String private, String public}) asked) {
    String? fingerprint;
    Directory? alone;
    try {
      alone = Directory.systemTemp.createTempSync('porelo-key-');
      // Absolute, since a link's relative target is read from the link's own folder.
      final link = Link(path.join(alone.path, 'key'))..createSync(path.absolute(asked.private));
      final answer = Process.runSync(openSsh('ssh-keygen'), ['-l', '-f', link.path]);
      final fields = '${answer.stdout}'.trim().split(RegExp(r'\s+'));
      if (answer.exitCode == 0 && fields.length > 1 && fields[1].startsWith('SHA256:')) fingerprint = fields[1];
    } on ProcessException {
      fingerprint = null;
    } on FileSystemException {
      // No link here (Windows without the right to make one), so nothing can be said.
      fingerprint = null;
    } finally {
      try {
        // The link goes, never what it points to.
        alone?.deleteSync(recursive: true);
      } on FileSystemException {
        // A folder left in the temporary folder holds a link only, no key.
      }
    }
    final belongs = fingerprint == null ? null : fingerprint == asked.public;
    setState(() {
      _pairAnsweredFor = asked.pair;
      _pairBelongs = belongs;
      _pairRefusal = belongs == false
          ? 'Your public ssh key ${asked.public} does not belong to the private key, whose key is $fingerprint. '
                'Choose the .pub file of that private key.'
          : null;
    });
    return belongs;
  }

  // A signing key kept from an earlier run is never replaced by a pinned one.
  bool _signingKeyKept = false;
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
      _secrets,
      _signingKey,
      _keyName,
      _scaleway,
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
    _protocolScroll.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted) return;
    _keepProtocolPosition();
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

  void _keepProtocolPosition() {
    if (_protocolUpdateScheduled || !_protocolScroll.hasClients) return;
    final position = _protocolScroll.position;
    final before = position.pixels;
    final follow = before >= position.maxScrollExtent - Sizes.hostProtocolEndThreshold;
    GlobalKey? anchor;
    double? anchorTop;
    if (!follow) {
      final viewport = _protocolViewport.currentContext?.findRenderObject();
      if (viewport is RenderBox && viewport.hasSize) {
        final top = viewport.localToGlobal(Offset.zero).dy;
        for (final key in _protocolRows) {
          final box = key.currentContext?.findRenderObject();
          if (box is! RenderBox || !box.hasSize) continue;
          final y = box.localToGlobal(Offset.zero).dy;
          if (y + box.size.height > top && y < top + viewport.size.height) {
            anchor = key;
            anchorTop = y;
            break;
          }
        }
      }
    }
    _protocolUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _protocolUpdateScheduled = false;
      if (!mounted || !_protocolScroll.hasClients) return;
      // A reader who scrolled after the update keeps control of the view.
      final position = _protocolScroll.position;
      if ((position.pixels - before).abs() > Sizes.hostProtocolEndThreshold) return;
      if (follow) {
        _protocolScroll.jumpTo(position.maxScrollExtent);
      } else {
        // Growing current steps can insert content above an earlier attempt being read.
        final box = anchor?.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize && anchorTop != null) {
          final delta = box.localToGlobal(Offset.zero).dy - anchorTop;
          _protocolScroll.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent));
        }
      }
    });
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
    tresor: '',
    folder: _folder,
    setupFolder: _setupFolder,
    repository: '',
    signingKey: _signingKey.text.trim(),
    identity: _identity.text.trim(),
    publicKey: _publicKey.text.trim(),
    collection: widget.debug ? _collection.text.trim() : '',
    collectionSha256: widget.debug ? _collectionSha256.text.trim() : '',
    vpnPeerPublicKey: _tunnel?.peerPublicKey ?? '',
    vpnPeerAddress: _tunnel == null ? '' : '10.73.0.2/32',
    vpnHostPublicKey: _tunnel?.hostPublicKey ?? '',
    forgeCa: widget.settings?.hostUp(widget.project)?.forgeCa,
    vaultKeys: [for (final key in _keys) key.name],
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
    _scaleway, _account, _publicKey, _identity,
    if (widget.debug) ...[_collection, _collectionSha256], //
  ].every((field) => field.text.trim().isNotEmpty);

  bool get _running =>
      _preparing || _finishingDown || _hostRun?.running == true || _session?.state == HostRunState.running;

  Future<void> _withFiles(Future<void> Function(HostFiles) use) =>
      withHostFiles(use, secretStore: widget.secretStore, hostFiles: widget.hostFiles);

  /// Lets go of a drive folder from an earlier setup: nothing reads it any more.
  Future<void> _forgetTheOldDrive() async {
    await widget.settings?.rememberTresorFolder(widget.project, null);
    if (mounted) {
      setState(() {
        _folder = null;
        _machineProblem = null;
      });
    }
  }

  Future<void> _addKey() async {
    try {
      HostFiles.checkName(_keyName.text);
      // The secrets file, machine.yml and the host's stop must all take the name, and each only once.
      SecretsFile.checkKeyName(_keyName.text);
      if (_keys.any((key) => key.name == _keyName.text)) {
        throw HostFilesRefused('A vault entry ${_keyName.text} is chosen already.');
      }
      final selected = await _pickFile();
      if (selected == null || !mounted) return;
      final file = path.normalize(path.absolute(desk.expandHome(selected.trim())));
      HostFiles.checkBasename(path.basename(file));
      if (!desk.isWindows) SecretsFile.checkPath(file);
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
    // The private key's listener brings its .pub along.
    setState(() => field.text = file);
  }

  Future<void> _up() async {
    if (_running) return;
    if (noSecretsFileHere(desk) case final reason?) {
      setState(() => _machineProblem = 'A server cannot be set up here: $reason.');
      return;
    }
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
        // The secrets file keeps the host's key; the files `up` uploads are written in this desktop's own folder.
        final hostPublicKey = await _hostKeyFromTheSecretsFile();
        if (!mounted) return;
        // The secrets file's script moves a key the drive held; one still there is a key in the clear, never ignored.
        if (_drivesKey case final left?
            when FileSystemEntity.typeSync(left, followLinks: false) != FileSystemEntityType.notFound) {
          throw HostFilesRefused(
            '$left still holds a host key while your secrets file keeps it. Open the secrets file again from its step, '
            'which moves it, or remove it.',
          );
        }
        await _withFiles((files) async {
          await files.publishBundle(project: widget.project, folder: _setupFolder, bytes: _bundle!, ownFolder: true);
          _tunnel = await files.prepare(
            project: widget.project,
            folder: _setupFolder,
            url: HostFiles.bundleUrl(widget.project),
            signingKey: File(_signingKey.text.trim()),
            keys: _keys,
            hostPublicKey: hostPublicKey,
            ownFolder: true,
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
      // Asked again on the next try: a drive's key that turned up since must move into the file first.
      _hostPublicKey = null;
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
      Future<String?>? closing;
      if (owner != null) {
        await owner.confirmDown(widget.project, session);
        // Started now and waited for last: neither the machines nor the VPN wait on the transport.
        closing = owner.closeHomeserver(widget.project);
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
      // Only Linux brings up a local VPN that needs cleanup after give-back.
      if (!(widget.linux ?? Platform.isLinux)) {
        _vpnDownConfirmed = true;
        await sayWhetherStillPublished(closing);
        return;
      }
      _givenBackMachine = Machine(
        name: '${widget.project} server',
        kind: 'host',
        hostProject: widget.project,
        socketPath: '',
      );
      owner?.rememberVpnToTakeDown(_givenBackMachine!);
      if (mounted) await _takeVpnDown();
      await sayWhetherStillPublished(closing);
    } finally {
      if (mounted) setState(() => _finishingDown = false);
    }
  }

  /// Says, beside what the give-back said, where this computer's homeserver is still published for the server.
  Future<void> sayWhetherStillPublished(Future<String?>? closing) async {
    final still = await closing;
    if (still == null || !mounted) return;
    setState(() => _machineProblem = [?_machineProblem, still].join(' '));
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
        linux: widget.linux,
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

  String? _fileProblem(String value, String label, {bool link = true}) {
    try {
      final expanded = desk.expandHome(value.trim());
      // Windows answers for a device as for a file, and reading it waits.
      if (_namesADevice(expanded)) return '$label names a Windows device: $expanded.';
      // A vault entry's link is refused, as the secrets file's script refuses it: what it points at can change.
      return switch (FileSystemEntity.typeSync(expanded, followLinks: link)) {
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
    // Refused before anything reads the file whole: a private key chosen here must not enter the interface.
    try {
      if (!_startsAsPublicKey(desk.expandHome(_signingKey.text.trim()))) {
        return 'The public key for signing commits is not a public key (.pub): ${_signingKey.text.trim()}.';
      }
    } on FileSystemException {
      return 'The public key for signing commits cannot be read: ${_signingKey.text.trim()}.';
    }
    for (final key in _keys) {
      final problem = _fileProblem(key.file.path, 'The file for vault entry ${key.name}', link: false);
      if (problem != null) return problem;
      // As the secrets file's script takes it: reached through no link on the way, and with content.
      try {
        final file = path.normalize(path.absolute(desk.expandHome(key.file.path)));
        if (!desk.isWindows && File(file).resolveSymbolicLinksSync() != file) {
          return 'The file for vault entry ${key.name} lies in a folder reached through a link: $file.';
        }
        if (File(file).lengthSync() == 0) return 'The file for vault entry ${key.name} is empty: $file.';
      } on FileSystemException {
        return 'The file for vault entry ${key.name} cannot be checked: ${key.file.path}.';
      }
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
      if (_startsAsPublicKey(identity)) return public;
    } on FileSystemException {
      return 'Cannot read the private ssh key file.';
    }
    return _fileProblem(_publicKey.text, 'Your public ssh key') ??
        (_pairRefusal == null ? null : 'Choose the public key that belongs to the private key.');
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
      title: 'The project',
      words:
          'The project’s verified bundle goes up to the server with the setup itself. Give the public key used to '
          'sign its commits, and the files of the vault entries the server is to have, which your secrets file keeps.',
      panel: (context) => _panel([
        if (Platform.isWindows)
          const Text('The server setup files and saved VPN connection can be read only by your Windows user.'),
        // Read only for a host key it may still hold, which the secrets file takes over: said, and let go of here.
        if (_folder case final folder?)
          Row(
            key: const Key('host-old-drive'),
            children: [
              Expanded(
                child: Text(
                  'A drive folder from an earlier setup, $folder, is read once more: a server key it still holds '
                  'moves into your secrets file.',
                ),
              ),
              TextButton(
                key: const Key('host-old-drive-forget'),
                onPressed: _running || _upStarted ? null : _forgetTheOldDrive,
                child: const Text('Forget it'),
              ),
            ],
          ),
        ...[
          _pathField(
            _signingKey,
            'Public key for signing commits (.pub)',
            'host-signing-key',
            mark: _signingKeyMark(context),
            refusal: _signingRefusal,
          ),
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
          _sourceProblem ?? _required([_signingKey], 'Give the public key used to sign commits.') ?? _driveFilesProblem,
      beforeNext: _checkBundle,
      summary: () => [
        'Project bundle: uploaded as /etc/porelo-host/setup/${widget.project}.bundle',
        'Public signing key: ${_signingKey.text}',
        for (final key in _keys) 'Vault entry ${key.name}: ${key.basename}, kept in your secrets file',
      ],
    ),
    WizardStep(
      title: 'Your ssh keys',
      words:
          'The private key on this computer logs in to the server. '
          'Its public key is installed on the server to let that login in. '
          'Choose the private key; its .pub file beside it is filled in, and a public key of another pair is refused.',
      panel: (context) => _panel([
        _pathField(_identity, 'Your private ssh key', 'host-identity'),
        _pathField(
          _publicKey,
          'Your public ssh key',
          'host-public-key',
          mark: _publicKeyMark(context),
          refusal: _pairRefusal,
        ),
      ]),
      check: () => _keysProblem,
      beforeNext: _checkPairForNext,
      summary: () => [
        'Private ssh key: ${_identity.text}',
        'Public ssh key: ${_publicKey.text}',
        if (!widget.debug) 'Server setup collection: ${hostCollection.version}',
      ],
    ),
    WizardStep(
      title: 'Your secrets file',
      words:
          'Your secrets file, secrets.kdbx, keeps the server’s VPN key and its vault passphrase under one master '
          'password, which you type into this program’s terminal, without echo; it goes straight to keepassxc-cli on '
          'this computer, and this program keeps none of it. Name the file you have, or where a new one is made. '
          'KeePassXC opens it too.',
      panel: (_) => _panel([
        _pathField(_secrets, 'Your secrets file (.kdbx)', 'host-secrets-file'),
        Text(
          _secretsExist
              ? 'It is there: setup opens it with its master password.'
              : 'It is not there yet: setup makes it, with a master password you choose.',
        ),
        // Read once at the start: said here, before any terminal asks a master password nothing could take.
        if (!keepassxcCliIsHere) ...[
          Builder(
            builder: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.small,
              children: [
                Icon(
                  Icons.error_outline,
                  key: const Key('host-secrets-file-refused'),
                  size: Sizes.mark,
                  color: Theme.of(context).colorScheme.error,
                  semanticLabel: 'Refused',
                ),
                const Expanded(
                  child: Text(
                    'KeePassXC\'s command line (keepassxc-cli) is not installed on this computer, so the file cannot '
                    'be opened. Install it in a terminal of your own, then press the button below again:',
                  ),
                ),
              ],
            ),
          ),
          const CommandToCopy(command: SecretsFile.installCli, textKey: Key('host-secrets-install')),
        ],
        Wrap(
          spacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              key: const Key('host-secrets-open'),
              onPressed: _running || _upStarted || _openingSecrets || _secretsProblem != null ? null : _openSecretsNow,
              child: Text(
                '${_secretsExist ? 'Open it now' : 'Make it now'}${keepassxcCliIsHere ? '' : ' (try again)'}',
              ),
            ),
            // Without keepassxc-cli the step says it once, above; an answer from before would say it twice.
            if (_secretsAnswer case final answer? when keepassxcCliIsHere)
              Text(answer, key: const Key('host-secrets-answer')),
          ],
        ),
      ]),
      check: () => _secretsProblem,
      summary: () => ['Secrets file: ${_secrets.text}${_secretsExist ? '' : ' (made when setup starts)'}'],
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

  String get _secretsPath => _expanded(_secrets.text.trim());

  /// Where the host's setup files are written on this desktop; never the drive, which has no part in the setup.
  late final String _setupFolder = widget.setupFolder ?? path.join(desk.configuration, 'hosts', widget.project);

  String? get _drivesKey =>
      _folder == null ? null : path.join(path.normalize(_folder!), 'porelo-host', 'wireguard.key');

  /// The secrets file opened from its own step, before anything is rented: what the person sets up once.
  Future<void> _openSecretsNow() async {
    // Looked at again on every press: one installed since the start counts at once, and none is said above.
    keepassxcCliIsHere = keepassxcCliThere();
    if (!keepassxcCliIsHere) {
      setState(() => _secretsAnswer = null);
      return;
    }
    setState(() {
      _openingSecrets = true;
      _secretsAnswer = null;
    });
    try {
      await _hostKeyFromTheSecretsFile();
      if (mounted) setState(() => _secretsAnswer = 'Ready: the file keeps the server’s keys.');
    } on HostFilesRefused catch (refusal) {
      if (mounted) setState(() => _secretsAnswer = refusal.message);
    } on FormatException catch (refusal) {
      if (mounted) setState(() => _secretsAnswer = refusal.message);
    } finally {
      if (mounted) setState(() => _openingSecrets = false);
    }
  }

  /// The host key's public half from the secrets file, opened once per file and kept for the setup that follows.
  Future<String> _hostKeyFromTheSecretsFile() async {
    final file = _secretsPath;
    final drivesKey = _drivesKey;
    // Kept for this file and this drive only: another drive may hold a key that has to move first.
    final keys = <String, String>{for (final key in _keys) key.name: key.file.absolute.path};
    // A file changed or replaced since it was opened is taken again, never the key kept for the old one: the vault
    // entries' files, the secrets file itself, and a key the drive still holds.
    String state(String? file) {
      if (file == null) return 'none';
      final stat = File(file).statSync();
      return '$file ${FileSystemEntity.typeSync(file, followLinks: false)} ${stat.size} '
          '${stat.modified.microsecondsSinceEpoch}';
    }

    ({String file, String drive, String keys}) asked() => (
      file: state(file),
      drive: state(drivesKey),
      keys: keys.entries.map((each) => '${each.key}=${state(each.value)}').join('\n'),
    );
    if (_hostPublicKey != null && _hostPublicKeyFor == asked()) return _hostPublicKey!;
    final open = widget.openSecretsFile ?? _openTheSecretsFile;
    final key = await open(
      file: file,
      project: widget.project,
      migrateKeyFrom: drivesKey != null && File(drivesKey).existsSync() ? drivesKey : null,
      keys: keys,
    );
    HostFiles.checkPublicKey(key);
    _hostPublicKey = key;
    // As opening left them: it writes the secrets file and moves the drive's key, which asks nothing new.
    _hostPublicKeyFor = asked();
    await widget.settings?.rememberSecretsFile(file);
    return key;
  }

  bool get _secretsExist => File(_secretsPath).existsSync();

  String? get _secretsProblem {
    if (_secrets.text.trim().isEmpty) return 'Give where your secrets file lies, or where a new one is made.';
    try {
      SecretsFile.checkPath(_secretsPath);
    } on FormatException catch (refusal) {
      return refusal.message;
    }
    final kind = FileSystemEntity.typeSync(_secretsPath, followLinks: false);
    if (kind != FileSystemEntityType.notFound && kind != FileSystemEntityType.file) {
      return 'The secrets file is a folder or a link, not a file.';
    }
    return null;
  }

  /// Opens the secrets file in a terminal here and answers the host key's public half, never its private one.
  Future<String> _openTheSecretsFile({
    required String file,
    required String project,
    String? migrateKeyFrom,
    Map<String, String> keys = const {},
  }) async {
    // Said before any terminal asks a master password that nothing could take.
    if (keepassxcCliMissing() case final missing?) throw HostFilesRefused(missing);
    final folder = await Directory.systemTemp.createTemp('porelo-host-key-');
    try {
      final out = path.join(folder.path, '$project.pub');
      final script = SecretsFile(file).prepareHost(
        host: project,
        project: project,
        create: !File(file).existsSync(),
        publicKeyOut: out,
        migrateKeyFrom: migrateKeyFrom,
        keys: keys,
      );
      var exit = -1;
      if (!mounted) throw const HostFilesRefused('The secrets file was not opened.');
      await runInATerminal(
        context,
        key: const Key('host-secrets-terminal'),
        title: 'Your secrets file',
        explanation:
            'Type the master password of your secrets file into this terminal; it is not shown. It goes straight to '
            'keepassxc-cli on this computer, and this program keeps none of it: it gets back only the public half of '
            'the server’s VPN key.',
        machine: Machine.local(),
        // Neither the caller's startup files nor an inherited trace may run in the shell that holds the secrets.
        command: [
          '/usr/bin/env',
          '-u',
          'BASH_ENV',
          '-u',
          'ENV',
          '-u',
          'SHELLOPTS',
          '-u',
          'BASHOPTS',
          '/bin/bash',
          '--noprofile',
          '--norc',
          '-c',
          script,
        ],
        shownCommand: 'keepassxc-cli opens $file and keeps the server’s keys for ${widget.project}',
        completed: 'The secrets file is ready.',
        onExit: (code) => exit = code,
        open: widget.openTerminal,
      );
      final written = File(out);
      if (exit != 0 || !await written.exists()) {
        throw const HostFilesRefused('The secrets file was not opened, so setup did not start.');
      }
      return (await written.readAsString()).trim();
    } finally {
      await folder.delete(recursive: true);
    }
  }

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
          actions: (_, run) => Wrap(
            spacing: Space.small,
            children: [
              if (_session != null) _copyProtocolButton(),
              if (_needsYou && !_takingDown) _askForTheStop(),
              OutlinedButton(
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
            ],
          ),
        );

  Widget _runDialog(BuildContext context) => AlertDialog(
    key: const Key('host-protocol'),
    title: Text('${widget.project} server'),
    content: SizedBox(width: Sizes.dialogMedium, child: _progress(context)),
    actions: [
      if (_session != null) _copyProtocolButton(),
      if (_needsYou) _askForTheStop(),
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
          if (started) _copyProtocolButton(),
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
        if (mounted) {
          _keepProtocolPosition();
          setState(() {});
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    final attempts = session?.attempts ?? const <HostAttemptRecord>[];
    _protocolRows = [];
    Widget anchored(Object identity, Widget child) {
      final key = _protocolKeys[identity] ??= GlobalKey();
      _protocolRows.add(key);
      return KeyedSubtree(key: key, child: child);
    }

    // An earlier attempt is chosen above the protocol and shown alone; the current one is shown by default.
    final earlier = attempts.length > 1 ? attempts.sublist(0, attempts.length - 1) : const <HostAttemptRecord>[];
    final shown = earlier.contains(_shownAttempt) ? _shownAttempt : null;
    final rows = shown != null
        ? <Widget>[for (final entry in shown.entries) _protocolRow(entry, current: false)]
        : <Widget>[
            if (session != null) ...<Widget>[
              if (attempts.isNotEmpty)
                for (final entry in attempts.last.entries) anchored(entry, _protocolRow(entry)),
              if (_hostRun?.interrupted == true && _hostRun?.givenBack != true) ...[
                const Text('Nothing runs now. Go on continues from where it stopped.'),
              ],
              if (session.state == HostRunState.running)
                if (session.timeLeftText case final text?) Text(text),
              if (session.state == HostRunState.busy) Text('Setup of ${widget.project} is still running from before.'),
              if (session.state == HostRunState.waiting && _takingDown)
                const Text('The host has not completed teardown. Your machines have been kept.'),
              if (session.fix != null &&
                  session.fix != session.said &&
                  !session.history.any((record) => record.step.fix == session.fix))
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
          ];
    final list = SizedBox(
      key: _protocolViewport,
      height: Sizes.hostProtocolHeight,
      child: Scrollbar(
        controller: _protocolScroll,
        thumbVisibility: true,
        child: ListView.builder(
          key: const Key('host-protocol-list'),
          controller: _protocolScroll,
          padding: const EdgeInsets.only(right: Space.normal),
          itemCount: rows.length,
          findChildIndexCallback: (key) {
            final index = rows.indexWhere((row) => row.key == key);
            return index < 0 ? null : index;
          },
          itemBuilder: (_, index) => rows[index],
        ),
      ),
    );
    if (earlier.isEmpty) return list;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<HostAttemptRecord?>(
          key: const Key('host-attempt'),
          value: shown,
          onChanged: (attempt) => setState(() => _shownAttempt = attempt),
          items: [
            const DropdownMenuItem<HostAttemptRecord?>(value: null, child: Text('Current attempt')),
            for (final attempt in earlier.reversed)
              DropdownMenuItem<HostAttemptRecord?>(value: attempt, child: Text(attempt.earlierLabel)),
          ],
        ),
        list,
      ],
    );
  }

  Widget _protocolRow(Object entry, {bool current = true}) => switch (entry) {
    final HostStepRecord record => _stepRow(record, current: current),
    final HostProtocolLine line => Text(line.text),
    final HostProtocolInterruption interruption => Text(_session!.interruptionLine(interruption)),
    _ => throw StateError('Unsupported public protocol entry.'),
  };

  Widget _copyProtocolButton() {
    final command = copyHostProtocolCommand(
      project: widget.project,
      copy: () => unawaited(Clipboard.setData(ClipboardData(text: _session!.protocolText))),
    );
    return TextButton.icon(
      key: const Key('host-copy-protocol'),
      onPressed: command.run,
      icon: const Icon(Icons.copy_outlined),
      label: Text(command.label),
    );
  }

  Widget _pathField(TextEditingController controller, String label, String key, {Widget? mark, String? refusal}) => Row(
    children: <Widget>[
      Expanded(
        child: _field(controller, label, key, namesHost: true, mark: mark, refusal: refusal),
      ),
      const SizedBox(width: Space.small),
      TextButton(
        onPressed: _running || _upStarted ? null : () => _chooseFile(controller),
        child: const Text('Choose…'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool namesHost = false,
    Widget? mark,
    String? refusal,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.small),
    child: TextField(
      key: Key(key),
      controller: controller,
      enabled: !_running,
      readOnly: namesHost && _upStarted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: mark == null ? null : Padding(padding: const EdgeInsets.all(Space.small), child: mark),
        errorText: refusal,
        errorMaxLines: 6,
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _stepRow(HostStepRecord record, {bool current = true}) => Row(
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
          key: current && record.step.fix != null && record.step.fix == _session!.fix ? const Key('host-fix') : null,
        ),
      ),
    ],
  );

  /// A stop, or a refusal of `up` that asks on a call of its own (the central forge's token, a vault entry).
  bool get _needsYou => _session?.state == HostRunState.waiting || (_hostRun?.asksOnItsOwn != null && !_running);

  Widget _askForTheStop() => KeyedSubtree(
    key: const Key('host-stop'),
    child: Builder(
      builder: (_) {
        final command = hostPreparationCommand(
          project: widget.project,
          home: Home.openedView,
          open: () => openHostStopDialog(
            context,
            run: _hostRun!,
            hostRuns: widget.hostRuns!,
            machines: widget.machines,
            settings: widget.settings,
            openTerminal: widget.openTerminal,
            needs: _hostRun!.asksOnItsOwn,
          ),
        ).unless(_running || _hostRun == null ? 'the host command is still running' : null);
        return FilledButton(
          key: const Key('host-complete-setup'),
          onPressed: command.available ? command.run : null,
          child: Text(command.label),
        );
      },
    ),
  );
}
