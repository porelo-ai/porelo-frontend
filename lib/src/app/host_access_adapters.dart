import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show ChangeNotifier;
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
class CoreHostAdminProof extends ChangeNotifier implements HostAdminProof {
  /// Constructor taking Core's identity verbs, or a process runner for them.
  CoreHostAdminProof({Identity? identity, RunHere? run}) : _identity = identity ?? Identity(run: run);

  final Identity _identity;
  HostAdminIdentity? _current;
  String _why = 'Your identity has not been read yet.';

  // Only the newest read is kept: an older one that ends later never brings back a key since taken away.
  int _generation = 0;

  /// The proven login and card key fingerprint as last read, or null.
  HostAdminIdentity? current() => _current;

  @override
  String? get whyNone => _current == null ? _why : null;

  @override
  Future<void> readAgain() async {
    final read = ++_generation;
    HostAdminIdentity? proven;
    String why;
    try {
      final card = await _identity.show();
      why = card.whyKeyUnusable ?? '';
      if (why.isEmpty) proven = HostAdminIdentity(card.login, card.fingerprint);
    } on NoIdentity catch (none) {
      why = none.words;
    } on RegistryRefusal catch (refused) {
      why = refused.words;
    } on Exception {
      why = "Porelo's answer on your identity could not be read. Try again.";
    }
    if (read != _generation) return;
    _current = proven;
    if (proven == null) _why = why;
    notifyListeners();
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
    required this.identity,
    this.proof,
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

  /// The proven host admin, whose joined card alone reaches root.
  final HostAdminIdentity? Function() identity;

  /// Read again before root is reached, so a key revoked or taken out of the agent reaches nothing.
  final HostAdminProof? proof;

  final RunHere _run;
  final RunHereWithBytes _send;
  final HostFileWriter _writer;
  final Map<String, String>? _environment;

  /// The host's own registry intake, root's alone.
  static const intake = '/usr/local/sbin/porelo-host-person registry --stdin';

  /// The host's read-only answer of what it applied, root's alone.
  static const statusVerb = '/usr/local/sbin/porelo-host-person registry status';

  /// Said when the host's helper does not know [statusVerb].
  static const olderHost = "The host's porelo-host is older than its registry status. Update porelo-host on the host.";

  @override
  Future<HostRegistryStatus> status(String host) async {
    checkHostName(host);
    final registry = this.registry() ?? (throw const RegistryRefusal(HostAccess.noRegistry));
    final config = await _refusedInWords(() => _config(host, registry));
    final Ran answer;
    try {
      answer = await _run('ssh', [..._root(config, host), statusVerb]);
    } on ProcessException {
      throw const RegistryRefusal('SSH could not run on this computer.');
    }
    if (answer.code != 0) {
      final words = _hostWords(answer);
      if (answer.code == 2 ||
          words.contains('unknown') ||
          answer.code == 64 && words.startsWith('porelo-host-person: use ')) {
        throw const RegistryRefusal(olderHost);
      }
      throw RegistryRefusal(words);
    }
    final Object? read;
    try {
      read = jsonDecode(answer.out.trim());
    } on FormatException {
      throw const RegistryRefusal('The host answered its registry status incompletely.');
    }
    if (read is! Map) throw const RegistryRefusal('The host answered its registry status incompletely.');
    if (read['host'] != host) throw const RegistryRefusal('The registry status names another host.');
    final commit = read['commit'];
    final pinned = read['pinned'];
    if (commit != null && (commit is! String || !_commit.hasMatch(commit)) ||
        pinned != null && (pinned is! String || !_fingerprint.hasMatch(pinned)) ||
        !read.containsKey('commit') ||
        !read.containsKey('pinned')) {
      throw const RegistryRefusal('The host answered its registry status incompletely.');
    }
    return HostRegistryStatus(
      host: host,
      revision: commit as String?,
      people: _people(read['persons']),
      words: commit == null
          ? 'The host has applied no registry yet.'
          : 'The host applied registry commit ${commit.substring(0, 12)}.',
    );
  }

  /// Intake applied the bundle already; sync sends nothing and confirms the host applied exactly [revision].
  @override
  Future<HostRegistryStatus> sync(String host, String revision) async {
    checkedRegistryRevision(revision);
    final answer = await status(host);
    if (answer.revision != revision) {
      throw RegistryRefusal(
        'The host has not applied the registry revision brought; it reports '
        '${answer.revision?.substring(0, 12) ?? 'none'}.',
      );
    }
    return answer;
  }

  static final _commit = RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$');
  static final _fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');

  /// The host's persons as [HostRegistryStatus.people]: an unfinished lock is locked, a login only named is absent.
  static Map<String, String> _people(Object? value) {
    const incomplete = RegistryRefusal('The host answered its persons incompletely.');
    if (value is! List) throw incomplete;
    final people = <String, String>{};
    for (final person in value) {
      if (person is! Map) throw incomplete;
      final login = person['login'];
      final state = person['state'];
      final hand = person['hand'];
      final projects = person['projects'];
      if (login is! String ||
          !RegExp(r'^[a-z][a-z0-9-]{0,30}$').hasMatch(login) ||
          hand is! bool ||
          projects is! List ||
          !projects.every(
            (each) =>
                each is Map && each['project'] is String && const ['project-admin', 'developer'].contains(each['role']),
          ) ||
          people.containsKey(login) ||
          (state == 'purged' && (hand || projects.isNotEmpty)) ||
          (state == 'named' && projects.isNotEmpty)) {
        throw incomplete;
      }
      final mapped = switch (state) {
        'active' => 'active',
        'locked' || 'pending' => 'locked',
        'purged' => 'purged',
        'named' => null,
        _ => throw incomplete,
      };
      if (mapped != null) people[login] = mapped;
    }
    return people;
  }

  /// SSH to root through the card's pinned [config]: no agent forwarding, no shared connection of the person's.
  static List<String> _root(String config, String host) => [
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
    '-o',
    'ProxyCommand=none',
    'root@$host',
  ];

  @override
  Future<void> upload(String host, String revision) async {
    checkHostName(host);
    checkedRegistryRevision(revision);
    final registry = this.registry() ?? (throw const RegistryRefusal(HostAccess.noRegistry));
    // Only what Core accepted now leaves this computer: a fetched commit it refused never does.
    if (registry.problem != null || revision != registry.accepted?.revision) {
      throw const RegistryRefusal(
        'Only the registry revision Porelo accepted now is brought to a host. Refresh the registry and try again.',
      );
    }
    await _refusedInWords(() async {
      final config = await _config(host, registry);
      final pinned = _pinned(registry, host);
      final since = settings.hostRegistryState(host).lastAppliedRevision;
      await privateDirectory(Directory(scratch), writer: _writer);
      final temporary = await _writer.createPrivateTemporary(Directory(scratch), prefix: 'registry-bundle-');
      try {
        final bundle = await _bundle(registry, temporary.path, revision);
        await _verify(
          bundle,
          host: host,
          revision: revision,
          pinned: pinned,
          since: since,
          card: _card(registry, host),
        );
        final answer = await _send('ssh', [..._root(config, host), intake], input: await File(bundle).readAsBytes());
        if (answer.code != 0) throw RegistryRefusal(_hostWords(answer));
        _checkTaken(answer.out, revision, host);
      } finally {
        // A folder that cannot be removed now never hides why the upload stopped.
        try {
          await temporary.delete(recursive: true);
        } on FileSystemException {
          // Left in the private scratch folder.
        }
      }
    });
  }

  /// Runs [work], saying a refused workspace or host file in words, as every refusal here is said.
  static Future<T> _refusedInWords<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on WorkspaceRefused catch (refused) {
      throw RegistryRefusal(refused.words);
    } on HostFilesRefused catch (refused) {
      throw RegistryRefusal(refused.message);
    }
  }

  /// The registry's verified card of [host], which the joined card and Core's verification must both match.
  static Map<String, dynamic> _card(Registry registry, String host) {
    final card = registry.hosts.where((each) => each.host == host).firstOrNull?.card;
    if (card == null) {
      throw RegistryRefusal('The accepted registry holds no card of $host yet. Publish it first.');
    }
    return card;
  }

  /// The pinned config the host's card published here: the card the registry verified, joined with the proven
  /// admin's own login and key, and its files exactly as the join wrote them.
  Future<String> _config(String host, Registry registry) async {
    await proof?.readAgain();
    final me = identity();
    if (me == null) {
      throw RegistryRefusal(proof?.whyNone ?? 'Your identity is not proven, so no host is reached as root.');
    }
    final verified = _card(registry, host);
    final joined = machines().where((machine) => machine.hostCard?.name == host && machine.sshConfig.isNotEmpty);
    if (joined.isEmpty) {
      throw RegistryRefusal(
        'No pinned SSH config for $host is kept here. Join $host with your card first: its root is reached with '
        'that card’s key.',
      );
    }
    final same = joined.where((machine) {
      final card = machine.hostCard!;
      return card.address == verified['address'] &&
          card.sshPort == verified['ssh_port'] &&
          card.hostKey == verified['ssh_host_key'];
    }).firstOrNull;
    if (same == null) {
      throw RegistryRefusal(
        'The card joined here for $host names another address, SSH port or host key than the registry’s verified '
        'card. Join $host again.',
      );
    }
    final card = same.hostCard!;
    if (card.login != me.login || _fingerprintOf(card.publicKey) != me.fingerprint) {
      throw RegistryRefusal(
        'The card joined here for $host uses another login or key than your proven card. Join $host again with it.',
      );
    }
    final environment = _environment ?? desk.environment;
    HostCardSsh.checkConfigPath(host, same.sshConfig, environment: environment, windows: desk.isWindows);
    await card.checkPublished(same.sshConfig, writer: _writer, environment: environment);
    return same.sshConfig;
  }

  static String _fingerprintOf(String key) {
    try {
      return 'SHA256:${base64Encode(sha256.convert(base64Decode(key.split(' ')[1])).bytes).replaceAll('=', '')}';
    } on FormatException {
      return '';
    }
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
    required Map<String, dynamic> card,
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
    final verified = answer is Map ? answer['host_card'] : null;
    if (answer is! Map ||
        answer['commit'] != revision ||
        verified is! Map ||
        verified['host'] != host ||
        verified['address'] != card['address'] ||
        verified['ssh_port'] != card['ssh_port'] ||
        verified['ssh_host_key'] != card['ssh_host_key']) {
      throw const RegistryRefusal('Porelo verified another registry state than the one to bring. Nothing was sent.');
    }
  }

  /// Checks the host's answer field by field: it took exactly [revision].
  static void _checkTaken(String out, String revision, String host) {
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
    // A host from before its registry status answers neither; one that does is held to both.
    if (answer.containsKey('host') && answer['host'] != host) {
      throw const RegistryRefusal('The host that took the registry names another host.');
    }
    if (answer.containsKey('persons')) _people(answer['persons']);
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
