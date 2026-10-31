import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart' show HostCardSsh, HostFileWriter, HostFilesRefused, checkHostName;

import 'access_checkout.dart' show privateDirectory;
import 'desk.dart';
import 'host_access.dart';
import 'host_access_contract.dart';
import 'identity.dart';
import 'machines.dart';
import 'registry.dart';
import 'run_here.dart';
import 'settings.dart';

/// Core's proven identity for host administration: the card kept here, while its key is usable now.
///
/// Usable means what `identity show --json` answers: the key not revoked, the card verified (`card_refused` null) and
/// the agent holding the key. Otherwise nobody is proven, and [whyNone] says why.
class CoreHostAdminProof implements HostAdminProof {
  /// Constructor taking Core's identity verbs, or a process runner for them.
  CoreHostAdminProof({Identity? identity, RunHere? run}) : _identity = identity ?? Identity(run: run);

  final Identity _identity;
  HostAdminIdentity? _current;
  String _why = 'Your identity has not been read yet.';

  /// The proven login and card key fingerprint as last read, or null.
  HostAdminIdentity? current() => _current;

  @override
  String? get whyNone => _current == null ? _why : null;

  @override
  Future<void> readAgain() async {
    try {
      final card = await _identity.show();
      if (card.whyKeyUnusable case final why?) return _none(why);
      _current = HostAdminIdentity(card.login, card.fingerprint);
    } on NoIdentity catch (none) {
      _none(none.words);
    } on RegistryRefusal catch (refused) {
      _none(refused.words);
    } on Exception {
      _none("Porelo's answer on your identity could not be read. Try again.");
    }
  }

  void _none(String why) {
    _current = null;
    _why = why;
  }
}

/// Brings an exact registry revision to a host as root, through the host card's own pinned SSH config.
///
/// The bundle is made in a private temporary folder from the registry checkout's objects, never in the checkout, and
/// removed afterwards; Core verifies it here before the host is given it. Root is reached with the config the card's
/// join published: its pinned host key, the card key alone and no agent forwarding, never `~/.ssh/config`.
class SshHostRegistryTransport implements HostRegistryTransport {
  /// Constructor taking the registry pages' registry, the watched machines, the confirmed host facts and a private
  /// scratch folder.
  SshHostRegistryTransport({
    required this.registry,
    required this.machines,
    required this.settings,
    required this.scratch,
    RunHere? run,
    RunHereWithBytes? send,
    HostFileWriter? writer,
    this._environment,
  }) : _run = run ?? runHere,
       _send = send ?? runHereWithBytes,
       _writer = writer ?? HostFileWriter();

  /// The registry of the address chosen now, or null before one was chosen.
  final Registry? Function() registry;

  /// The machines watched here; the host's card machine names its pinned SSH config.
  final List<Machine> Function() machines;

  /// The last registry revision each host confirmed.
  final Settings settings;

  /// A private folder each bundle's temporary folder is made in.
  final String scratch;

  final RunHere _run;
  final RunHereWithBytes _send;
  final HostFileWriter _writer;
  final Map<String, String>? _environment;

  /// The host's own registry intake, root's alone.
  static const intake = '/usr/local/sbin/porelo-host-person registry --stdin';

  /// Why status cannot be asked: the host serves no verb that reads its applied registry.
  static const noStatus =
      'The host cannot be asked which registry it applied yet: porelo-host-person serves no read-only registry '
      'status that names the host, its applied commit and each person’s membership.';

  /// Why sync cannot be asked: the host applies the registry while taking it, and confirms no membership.
  static const noSync =
      'The host cannot confirm a registry sync yet: porelo-host-person applies the registry while taking it, and '
      'its answer names neither the host nor each person’s membership.';

  @override
  Future<HostRegistryStatus> status(String host) => Future.error(const RegistryRefusal(noStatus));

  @override
  Future<HostRegistryStatus> sync(String host, String revision) => Future.error(const RegistryRefusal(noSync));

  @override
  Future<void> upload(String host, String revision) async {
    checkHostName(host);
    checkedRegistryRevision(revision);
    final registry = this.registry() ?? (throw const RegistryRefusal(HostAccess.noRegistry));
    final config = _config(host);
    final pinned = _pinned(registry, host);
    final since = settings.hostRegistryState(host).lastAppliedRevision;
    await privateDirectory(Directory(scratch), writer: _writer);
    final temporary = await _writer.createPrivateTemporary(Directory(scratch), prefix: 'registry-bundle-');
    try {
      final bundle = await _bundle(registry, temporary.path, revision);
      await _verify(bundle, host: host, revision: revision, pinned: pinned, since: since);
      final answer = await _send('ssh', [
        '-F',
        config,
        '-T',
        '-o',
        'BatchMode=yes',
        '-o',
        'ForwardAgent=no',
        '-o',
        'ControlMaster=no',
        '-o',
        'ControlPath=none',
        'root@$host',
        intake,
      ], input: await File(bundle).readAsBytes());
      if (answer.code != 0) throw RegistryRefusal(_hostWords(answer));
      _checkTaken(answer.out, revision);
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  /// The pinned config the host's card published here, checked to lie where Core and the join put it.
  String _config(String host) {
    final card = machines()
        .where((machine) => machine.hostCard?.name == host && machine.sshConfig.isNotEmpty)
        .firstOrNull;
    if (card == null) {
      throw RegistryRefusal(
        'No pinned SSH config for $host is kept here. Join $host with your card first: its root is reached with '
        'that card’s key.',
      );
    }
    try {
      HostCardSsh.checkConfigPath(
        host,
        card.sshConfig,
        environment: _environment ?? desk.environment,
        windows: desk.isWindows,
      );
    } on HostFilesRefused catch (refused) {
      throw RegistryRefusal(refused.message);
    }
    return card.sshConfig;
  }

  /// The key that signed the host's accepted card, which Core verifies the bundle against.
  static String _pinned(Registry registry, String host) {
    final card = registry.hosts.where((each) => each.host == host).firstOrNull?.card;
    final signer = card?['signed_by'];
    if (signer is! String || !RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(signer)) {
      throw RegistryRefusal('The accepted registry holds no signed card of $host yet. Publish it first.');
    }
    return signer;
  }

  /// A bundle of the checkout's [revision] as `refs/heads/main`, made in a bare repository of its own.
  Future<String> _bundle(Registry registry, String folder, String revision) async {
    final repository = path.join(folder, 'registry.git');
    final bundle = path.join(folder, 'registry.bundle');
    // The checkout's objects are read, never written: its own configuration and hooks take no part.
    final objects = {'GIT_ALTERNATE_OBJECT_DIRECTORIES': path.join(registry.checkout.folder, '.git', 'objects')};
    await _git(['init', '--quiet', '--bare', repository]);
    await _git(['--git-dir', repository, 'update-ref', 'refs/heads/main', revision], objects);
    await _git(['--git-dir', repository, 'bundle', 'create', '--quiet', bundle, 'refs/heads/main'], objects);
    return bundle;
  }

  Future<void> _git(List<String> arguments, [Map<String, String> extra = const {}]) async {
    final Ran result;
    try {
      result = await _run(
        'git',
        arguments,
        environment: {
          'GIT_CONFIG_GLOBAL': '/dev/null',
          'GIT_CONFIG_NOSYSTEM': '1',
          'GIT_TERMINAL_PROMPT': '0',
          ...extra,
        },
      );
    } on ProcessException {
      throw const RegistryRefusal('Git could not run to bundle the registry.');
    }
    if (result.code != 0) {
      throw const RegistryRefusal('The registry checkout does not hold the revision to bring. Refresh the registry.');
    }
  }

  /// Core's verdict on the bundle as the host will judge it, before anything leaves this computer.
  Future<void> _verify(
    String bundle, {
    required String host,
    required String revision,
    required String pinned,
    String? since,
  }) async {
    final Ran result;
    try {
      result = await _run('porelo', [
        'registry',
        'verify',
        '--repository',
        bundle,
        '--host',
        host,
        '--pinned',
        pinned,
        if (since != null) ...['--since', since],
        '--json',
      ]);
    } on ProcessException {
      throw const RegistryRefusal('Porelo is not installed on this computer.');
    }
    if (result.code != 0) {
      throw RegistryRefusal(
        _lastLine(result.err, prefix: 'porelo: ') ?? 'Porelo refused the registry bundle (exit ${result.code}).',
      );
    }
    final Object? answer;
    try {
      answer = jsonDecode(result.out);
    } on FormatException {
      throw const RegistryRefusal('Porelo answered the registry verification incompletely.');
    }
    final card = answer is Map ? answer['host_card'] : null;
    if (answer is! Map || answer['commit'] != revision || card is! Map || card['host'] != host) {
      throw const RegistryRefusal('Porelo verified another registry state than the one to bring. Nothing was sent.');
    }
  }

  /// Checks the host's answer field by field: it took exactly [revision].
  static void _checkTaken(String out, String revision) {
    final Object? answer;
    try {
      answer = jsonDecode(out.trim());
    } on FormatException {
      throw const RegistryRefusal('The host answered the registry intake incompletely.');
    }
    bool strings(Object? value) => value is List && value.every((each) => each is String);
    if (answer is! Map ||
        answer['commit'] is! String ||
        answer['pinned'] is! String ||
        !RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(answer['pinned'] as String) ||
        !strings(answer['projects']) ||
        !strings(answer['dropped']) ||
        !strings(answer['revoked']) ||
        !strings(answer['refused']) ||
        answer['unchanged'] is! bool) {
      throw const RegistryRefusal('The host answered the registry intake incompletely.');
    }
    if (answer['commit'] != revision) {
      throw const RegistryRefusal('The host took another registry revision than the one brought.');
    }
  }

  /// The host's own refusal, or SSH's when the host was not reached; never more than its last line.
  static String _hostWords(Ran answer) =>
      _lastLine(answer.err, prefix: 'porelo-host-person: ') ??
      (answer.code == 255 ? _lastLine(answer.err) : null) ??
      'The host refused the registry (exit ${answer.code}).';

  static String? _lastLine(String text, {String? prefix}) {
    final lines = [
      for (final line in const LineSplitter().convert(text))
        if (line.trim().isNotEmpty && (prefix == null || line.startsWith(prefix)))
          line.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '?').trim(),
    ];
    return lines.lastOrNull;
  }
}
