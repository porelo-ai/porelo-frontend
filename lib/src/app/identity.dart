import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'host_access_contract.dart' show checkedRegistryRevision;
import 'registry.dart' show RegistryContact, RegistryRefusal;
import 'run_here.dart';

/// Whether the agent `SSH_AUTH_SOCK` names serves the card's key, as Core answers it.
enum AgentState {
  /// The agent holds the card's key.
  holds,

  /// An agent answers but does not hold it: KeePassXC locked or the entry not loaded.
  notHeld,

  /// No agent is reachable.
  absent,

  /// A word this interface does not know yet, never read as holding.
  unknown,
}

/// How one registry holds the person's card.
enum FiledState {
  /// The registry's accepted card is this card.
  done,

  /// Filed and not yet accepted.
  pending,

  /// The registry refused it.
  refused,

  /// No card for the login.
  absent,

  /// A word this interface does not know yet, never read as done.
  unknown,
}

/// Where one place of an identity operation stands.
enum PlaceState {
  /// The place took the new card.
  done,

  /// The place has not taken it yet.
  pending,

  /// The place refused it.
  refused,

  /// A dry run's place, nothing done.
  planned,

  /// A word this interface does not know yet, never read as done.
  unknown,
}

T _enum<T>(Object? word, Map<String, T> names, T unknown) {
  if (word is! String) throw const FormatException('Core did not answer a state word.');
  return names[word] ?? unknown;
}

AgentState _agent(Object? word) => _enum(word, const {
  'holds': AgentState.holds,
  'not-held': AgentState.notHeld,
  'absent': AgentState.absent,
}, AgentState.unknown);

FiledState _filed(Object? word) => _enum(word, const {
  'done': FiledState.done,
  'pending': FiledState.pending,
  'refused': FiledState.refused,
  'absent': FiledState.absent,
}, FiledState.unknown);

PlaceState _place(Object? word) => _enum(word, const {
  'done': PlaceState.done,
  'pending': PlaceState.pending,
  'refused': PlaceState.refused,
  'planned': PlaceState.planned,
}, PlaceState.unknown);

/// One registry this machine reads and how it holds the person's card.
@immutable
class IdentityRegistry {
  /// Constructor taking every field Core answers.
  const IdentityRegistry({
    required this.address,
    required this.filed,
    required this.filedWord,
    required this.revision,
    required this.mayFile,
    required this.whoMay,
    this.why,
  });

  /// The checkout's `origin` exactly as git answers it.
  final String address;

  /// How it holds the card.
  final FiledState filed;

  /// Core's own word, shown when [filed] is unknown.
  final String filedWord;

  /// The registry revision read, absent when Core names none.
  final String? revision;

  /// Whether the person's own key may file the card here.
  final bool mayFile;

  /// The owners who may file it when [mayFile] is false.
  final List<RegistryContact> whoMay;

  /// Why the registry refused it, when it did.
  final String? why;
}

/// The central forge's listing of the person's public keys.
@immutable
class ForgeKeyListing {
  /// Constructor taking every field Core answers.
  const ForgeKeyListing({
    required this.login,
    required this.keyListed,
    required this.keysUrl,
    required this.accountUrl,
  });

  /// The person's login at the forge.
  final String login;

  /// Whether the key is listed; null when the forge lists no keys or could not be asked.
  final bool? keyListed;

  /// The forge's public list of the person's keys.
  final String keysUrl;

  /// Where the person adds a key.
  final String accountUrl;
}

/// An identity operation started and not finished.
@immutable
class PendingIdentityOperation {
  /// Constructor taking the operation's ID and action.
  const PendingIdentityOperation({required this.id, required this.action});

  /// The caller's or Core's operation ID.
  final String id;

  /// `rotate` or `revoke-lost`, or a word this interface does not know.
  final String action;
}

/// The person's card as `identity show` answers it.
@immutable
class IdentityCard {
  /// Constructor taking every field Core answers.
  const IdentityCard({
    required this.login,
    required this.name,
    required this.email,
    required this.fingerprint,
    required this.key,
    required this.created,
    required this.expires,
    required this.predecessor,
    required this.card,
    required this.agent,
    required this.agentWord,
    required this.revoked,
    required this.cardRefused,
    required this.registry,
    required this.forge,
    required this.pending,
  });

  /// The person's login.
  final String login;

  /// The person's name.
  final String name;

  /// The card's address, absent when it names none.
  final String? email;

  /// The key's fingerprint, `SHA256:...`.
  final String fingerprint;

  /// The public key, `ssh-ed25519 AAAA...`.
  final String key;

  /// The day the card was made.
  final String created;

  /// The day the card expires.
  final String expires;

  /// The previous key's fingerprint, absent for a first card.
  final String? predecessor;

  /// The card's text.
  final String card;

  /// Whether the agent serves the key.
  final AgentState agent;

  /// Core's own agent word, shown when [agent] is unknown.
  final String agentWord;

  /// Whether the key is revoked here or by a registry.
  final bool revoked;

  /// Why the card does not verify, absent when it does.
  final String? cardRefused;

  /// Every registry this machine reads.
  final List<IdentityRegistry> registry;

  /// The forge listing, absent when no registry is read.
  final ForgeKeyListing? forge;

  /// Operations started and not finished.
  final List<PendingIdentityOperation> pending;

  /// Why nothing that needs this card's key may be offered now, or null when it may.
  String? get whyKeyUnusable {
    if (revoked) return 'Your key is revoked. Only “I lost my key” makes a new one now.';
    if (cardRefused case final why?) return 'Your card does not verify: $why';
    return switch (agent) {
      AgentState.holds => null,
      AgentState.notHeld => 'Your SSH agent does not hold your key. Open KeePassXC and load the entry.',
      AgentState.absent => 'No SSH agent is reachable. Start KeePassXC with its SSH agent integration.',
      AgentState.unknown => 'Core answered “$agentWord” for your SSH agent, which this interface does not know.',
    };
  }
}

/// One place an identity operation publishes to.
@immutable
class PublishedPlace {
  /// Constructor taking every field Core answers.
  const PublishedPlace({
    required this.where,
    required this.name,
    required this.status,
    required this.statusWord,
    required this.why,
    required this.whoMay,
  });

  /// `registry`, `project`, `host`, or a word this interface does not know.
  final String where;

  /// The registry's address, the project's or the host's name.
  final String name;

  /// Where the place stands.
  final PlaceState status;

  /// Core's own word, shown when [status] is unknown.
  final String statusWord;

  /// Why it waits or was refused.
  final String? why;

  /// Who must accept it.
  final List<RegistryContact> whoMay;
}

/// The answer of `identity rotate`, `revoke --lost`, `publish --id` and `status --id`.
@immutable
class IdentityOperation {
  /// Constructor taking every field Core answers.
  const IdentityOperation({
    required this.id,
    required this.action,
    required this.fingerprint,
    required this.predecessor,
    required this.published,
  });

  /// The operation's ID, the one a Retry sends.
  final String id;

  /// `rotate` or `revoke-lost`.
  final String action;

  /// The new key's fingerprint.
  final String fingerprint;

  /// The old key's fingerprint.
  final String predecessor;

  /// Each place and where it stands.
  final List<PublishedPlace> published;

  /// Whether every place is done; an unknown word is never done.
  bool get finished => published.isNotEmpty && published.every((place) => place.status == PlaceState.done);
}

/// A host whose vault a lost key resets.
@immutable
class VaultReset {
  /// Constructor taking the host and what happens to its vault.
  const VaultReset({required this.host, required this.vault});

  /// The host's name.
  final String host;

  /// What happens to the vault, `reset` as Core answers it.
  final String vault;
}

/// The sign-ins on a host that are made again after its vault is reset.
@immutable
class SignInsAgain {
  /// Constructor taking the host and the entry names.
  const SignInsAgain({required this.host, required this.entries});

  /// The host's name.
  final String host;

  /// Vault entry names, never values.
  final List<String> entries;
}

/// What `revoke --lost --dry-run` says a confirmed run would do.
@immutable
class LostKeyPlan {
  /// Constructor taking every field Core answers.
  const LostKeyPlan({required this.places, required this.hosts, required this.signIns});

  /// Each place and who must accept the replacement.
  final List<PublishedPlace> places;

  /// The hosts whose vault is made again.
  final List<VaultReset> hosts;

  /// The sign-ins made again per host.
  final List<SignInsAgain> signIns;
}

/// What `identity create` answers.
@immutable
class IdentityCreated {
  /// Constructor taking every field Core answers.
  const IdentityCreated({
    required this.login,
    required this.fingerprint,
    required this.key,
    required this.card,
    required this.agent,
    required this.forge,
    required this.next,
  });

  /// The person's login.
  final String login;

  /// The key's fingerprint.
  final String fingerprint;

  /// The public key.
  final String key;

  /// The card's text.
  final String card;

  /// Whether the agent serves the key.
  final AgentState agent;

  /// The forge listing, absent when no registry is read.
  final ForgeKeyListing? forge;

  /// What Core says comes next, such as `file-card`.
  final List<String> next;
}

/// One key the agent serves, with Core's verdict for "use my existing key".
@immutable
class AgentKey {
  /// Constructor taking every field Core answers.
  const AgentKey({
    required this.fingerprint,
    required this.key,
    required this.comment,
    required this.usable,
    required this.reason,
    required this.login,
    required this.keyListed,
  });

  /// The key's fingerprint.
  final String fingerprint;

  /// The public key.
  final String key;

  /// The agent's comment for it.
  final String comment;

  /// Whether `create --key` would take it.
  final bool usable;

  /// Why not, when it is not usable.
  final String? reason;

  /// The other card's login for `key-on-another-card`.
  final String? login;

  /// Whether the forge lists it; null without a registry read or a listing.
  final bool? keyListed;

  /// Why it cannot be used, in words, or null when it can.
  String? get whyNot => usable
      ? null
      : switch (reason) {
          'key-not-ed25519' => 'Not an Ed25519 key.',
          'key-on-another-card' => 'Already on the card of ${login ?? 'another person'}.',
          'revoked' => 'This key is revoked.',
          _ => 'Core does not offer it (${reason ?? 'no reason given'}).',
        };
}

/// What `registry file card` answers: the commit made in the checkout, not yet pushed.
@immutable
class CardFiled {
  /// Constructor taking the commit and the card's path in the registry.
  const CardFiled({required this.commit, required this.path});

  /// The commit made in the checkout.
  final String commit;

  /// The card's path in the registry.
  final String path;
}

/// The agent's keys, read through a small seam so a test can stand in.
abstract interface class AgentKeyList {
  /// The keys the agent serves, in its order; throws [IdentityRefused] with `agent-absent` when none answers.
  Future<List<AgentKey>> keys();
}

/// Core refused or could not answer; carries its typed reason when it gave one.
class IdentityRefused extends RegistryRefusal {
  /// Constructor taking the exit code, the typed reason and Core's words.
  const IdentityRefused(super.words, {required this.code, this.reason, this.login, super.whoMay});

  /// The exit code Core ended with.
  final int code;

  /// Core's fixed kebab-case reason, absent when it named none.
  final String? reason;

  /// The other login of `key-on-another-card`.
  final String? login;
}

/// The person has no card yet: the first start.
class NoIdentity implements Exception {
  /// Constructor taking Core's words.
  const NoIdentity(this.words);

  /// Core's words, for a person.
  final String words;
}

/// Why `identity backup-key` cannot run here yet.
const backupKeyRefusal = 'Waits for Core: the backup key is not built yet.';

/// Typed refusals Core gives before it made anything, so no operation exists under the ID.
const nothingMade = {
  'key-not-in-agent',
  'key-not-ed25519',
  'key-on-another-card',
  'revoked',
  'key-store-missing',
  'key-store-refused',
  'identity-exists',
};

/// An identity operation ID in Core's pattern.
final operationIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

/// A fresh operation ID for [action], unique enough that two starts never share one.
String newOperationId(String action, {DateTime? now, Random? random}) {
  final at = (now ?? DateTime.now()).toUtc();
  final day = '${at.year}${at.month.toString().padLeft(2, '0')}${at.day.toString().padLeft(2, '0')}';
  final tail = List.generate(6, (_) => (random ?? Random.secure()).nextInt(16).toRadixString(16)).join();
  return '$action-$day-$tail';
}

/// Core's `porelo identity` verbs, every answer checked field by field.
class Identity implements AgentKeyList {
  /// Constructor taking the process runner, a fake in tests.
  Identity({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  /// Reads the person's card; throws [NoIdentity] when none is kept.
  Future<IdentityCard> show() async {
    final answer = await _call(['identity', 'show', '--json']);
    return _card(answer);
  }

  @override
  Future<List<AgentKey>> keys() async {
    final answer = await _call(['identity', 'keys', '--json']);
    final keys = answer['keys'];
    if (keys is! List) throw const FormatException('Core did not list the agent keys.');
    return List.unmodifiable(keys.map(_agentKey));
  }

  /// Makes the card for an existing key the agent serves, named by its fingerprint.
  Future<IdentityCreated> createWithKey({
    required String login,
    required String name,
    String? email,
    required String fingerprint,
  }) async {
    final answer = await _call([
      'identity',
      'create',
      '--login',
      login,
      '--name',
      name,
      if (email != null && email.isNotEmpty) ...['--email', email],
      '--key',
      _fingerprint(fingerprint),
      '--json',
    ]);
    return IdentityCreated(
      login: _text(answer, 'login'),
      fingerprint: _fingerprint(_text(answer, 'fingerprint')),
      key: _key(_text(answer, 'key')),
      card: _text(answer, 'card'),
      agent: _agent(answer['agent']),
      forge: _forge(answer['forge']),
      next: _strings(answer['next']),
    );
  }

  /// The command a terminal runs to make a new key in KeePassXC and its card.
  static List<String> createInKeepassxc({
    required String login,
    required String name,
    String? email,
    required String database,
    String? entry,
  }) => [
    'porelo',
    'identity',
    'create',
    '--login',
    login,
    '--name',
    name,
    if (email != null && email.isNotEmpty) ...['--email', email],
    ..._keepassxc(database, entry),
    '--json',
  ];

  /// Changes the key to [fingerprint], an existing key the agent serves, under operation [id].
  Future<IdentityOperation> rotate({required String fingerprint, required String id}) async =>
      _operation(await _call(['identity', 'rotate', '--key', _fingerprint(fingerprint), '--id', _id(id), '--json']));

  /// The command a terminal runs to change the key to a new one in KeePassXC under operation [id].
  static List<String> rotateInKeepassxc({required String database, String? entry, required String id}) => [
    'porelo',
    'identity',
    'rotate',
    ..._keepassxc(database, entry),
    '--id',
    _id(id),
    '--json',
  ];

  /// Sends only the places of operation [id] that are not done.
  Future<IdentityOperation> publish(String id) async =>
      _operation(await _call(['identity', 'publish', '--id', _id(id), '--json']));

  /// Reads operation [id] back, changing nothing.
  Future<IdentityOperation> status(String id) async =>
      _operation(await _call(['identity', 'status', '--id', _id(id), '--json']));

  /// What replacing a lost key would do, making nothing: by an agent's [fingerprint] or a new key in [database].
  Future<LostKeyPlan> planLostKey({String? fingerprint, String? database, String? entry}) async {
    final answer = await _call([
      'identity',
      'revoke',
      '--lost',
      ..._successor(fingerprint, database, entry),
      '--dry-run',
      '--json',
    ]);
    final places = answer['places'];
    final hosts = answer['hosts'];
    final signIns = answer['sign_ins'];
    if (places is! List || hosts is! List || signIns is! List) {
      throw const FormatException('Core did not answer the whole lost-key plan.');
    }
    return LostKeyPlan(
      places: List.unmodifiable(places.map(_publishedPlace)),
      hosts: List.unmodifiable(
        hosts.map((host) {
          if (host is! Map<String, dynamic>) throw const FormatException('Invalid host in the plan.');
          return VaultReset(host: _text(host, 'host'), vault: _text(host, 'vault'));
        }),
      ),
      signIns: List.unmodifiable(
        signIns.map((signIn) {
          if (signIn is! Map<String, dynamic>) throw const FormatException('Invalid sign-ins in the plan.');
          return SignInsAgain(host: _text(signIn, 'host'), entries: _strings(signIn['entries']));
        }),
      ),
    );
  }

  /// Replaces a lost key by [fingerprint] under operation [id], after the plan was confirmed.
  Future<IdentityOperation> replaceLostKey({required String fingerprint, required String id}) async => _operation(
    await _call(['identity', 'revoke', '--lost', '--key', _fingerprint(fingerprint), '--id', _id(id), '--json']),
  );

  /// The command a terminal runs to replace a lost key by a new one in KeePassXC under operation [id].
  static List<String> replaceLostKeyInKeepassxc({required String database, String? entry, required String id}) => [
    'porelo',
    'identity',
    'revoke',
    '--lost',
    ..._keepassxc(database, entry),
    '--id',
    _id(id),
    '--json',
  ];

  /// Commits [card] to the registry [checkout] against [base] under request [id]; pushes nothing.
  Future<CardFiled> fileCard({
    required String checkout,
    required String card,
    required String id,
    required String base,
  }) async {
    if (checkout.isEmpty || card.isEmpty) throw const FormatException('No checkout or card file to file.');
    final answer = await _call([
      'registry',
      'file',
      'card',
      checkout,
      '--card',
      card,
      '--id',
      _id(id),
      '--base',
      checkedRegistryRevision(base),
      '--json',
    ]);
    return CardFiled(commit: checkedRegistryRevision(_text(answer, 'commit')), path: _text(answer, 'path'));
  }

  /// Where Core keeps the person's card: `$XDG_CONFIG_HOME/porelo/identity/card`.
  static String cardFile(Map<String, String> environment) {
    final config = environment['XDG_CONFIG_HOME'];
    final base = config != null && config.isNotEmpty ? config : '${environment['HOME'] ?? ''}/.config';
    return '$base/porelo/identity/card';
  }

  static List<String> _successor(String? fingerprint, String? database, String? entry) {
    if ((fingerprint == null) == (database == null)) throw const FormatException('Name exactly one new key.');
    return fingerprint != null ? ['--key', _fingerprint(fingerprint)] : _keepassxc(database!, entry);
  }

  /// Refuses until Core builds the backup key.
  Future<Never> backupKey() async => throw const IdentityRefused(backupKeyRefusal, code: 65, reason: 'not-built');

  static List<String> _keepassxc(String database, String? entry) {
    if (database.trim().isEmpty) throw const FormatException('Name your KeePassXC database file.');
    return [
      '--keepassxc',
      database,
      if (entry != null && entry.isNotEmpty) ...['--entry', entry],
    ];
  }

  Future<Map<String, dynamic>> _call(List<String> arguments) async {
    final ran = await _run('porelo', arguments);
    if (ran.code == 0) return _object(ran.out);
    final typed = _typed(ran.out);
    final reason = typed?['reason'] is String ? typed!['reason'] as String : null;
    final words = typed?['words'] is String ? typed!['words'] as String : null;
    if (ran.code == 65 && reason == 'no-identity') throw NoIdentity(words ?? 'No card is kept here yet.');
    throw IdentityRefused(
      words ?? _exitWords(ran.code),
      code: ran.code,
      reason: reason,
      login: typed?['login'] is String ? typed!['login'] as String : null,
      whoMay: typed != null && typed['who_may'] is List ? _contacts(typed['who_may']) : const [],
    );
  }

  static String _exitWords(int code) => switch (code) {
    64 => 'Core did not take this call.',
    65 => 'Core refused it.',
    66 => 'Core could not read the card or key file.',
    69 => 'A service Core needs could not be reached.',
    70 => 'Core failed inside.',
    77 => 'The vault was opened by another key.',
    _ => 'Core ended with $code.',
  };

  /// Core's typed refusal in [out], or null when it holds none.
  static ({String reason, String words})? typedRefusal(String out) {
    final typed = _typed(out.trim());
    final reason = typed?['reason'];
    if (reason is! String) return null;
    final words = typed?['words'];
    return (reason: reason, words: words is String ? words : reason);
  }

  static Map<String, dynamic>? _typed(String out) {
    try {
      final value = jsonDecode(out);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _object(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) throw const FormatException('Core did not return a JSON object.');
    return value;
  }

  static String _text(Map<String, dynamic> value, String field) {
    final text = value[field];
    if (text is! String || text.isEmpty) throw FormatException('Core did not answer $field.');
    return text;
  }

  static String? _textOrNull(Map<String, dynamic> value, String field) {
    if (!value.containsKey(field)) throw FormatException('Core did not answer $field.');
    final text = value[field];
    if (text != null && text is! String) throw FormatException('Core answered $field in another shape.');
    return text as String?;
  }

  static bool _bool(Map<String, dynamic> value, String field) {
    final flag = value[field];
    if (flag is! bool) throw FormatException('Core did not answer $field.');
    return flag;
  }

  static bool? _boolOrNull(Map<String, dynamic> value, String field) {
    if (!value.containsKey(field)) throw FormatException('Core did not answer $field.');
    final flag = value[field];
    if (flag != null && flag is! bool) throw FormatException('Core answered $field in another shape.');
    return flag as bool?;
  }

  static List<String> _strings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Core did not answer a list of words.');
    }
    return List.unmodifiable(value.cast<String>());
  }

  static String _fingerprint(String value) {
    if (!value.startsWith('SHA256:') || value.length < 8 || value.contains(RegExp(r'\s'))) {
      throw const FormatException('Not a SHA256 fingerprint.');
    }
    return value;
  }

  static String _key(String value) {
    if (!RegExp(r'^ssh-ed25519 [A-Za-z0-9+/=]+$').hasMatch(value)) {
      throw const FormatException('Core did not answer an Ed25519 key.');
    }
    return value;
  }

  static String _id(String id) {
    if (!operationIdPattern.hasMatch(id)) throw const FormatException('Not an operation ID.');
    return id;
  }

  static List<RegistryContact> _contacts(Object? value) {
    if (value is! List) throw const FormatException('Core did not answer who may.');
    return List.unmodifiable(
      value.map((contact) {
        if (contact is! Map<String, dynamic>) throw const FormatException('Invalid contact.');
        return RegistryContact(
          login: _text(contact, 'login'),
          name: _text(contact, 'name'),
          email: _textOrNull(contact, 'email'),
        );
      }),
    );
  }

  static ForgeKeyListing? _forge(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid forge listing.');
    return ForgeKeyListing(
      login: _text(value, 'login'),
      keyListed: _boolOrNull(value, 'key_listed'),
      keysUrl: _text(value, 'keys_url'),
      accountUrl: _text(value, 'account_url'),
    );
  }

  static IdentityCard _card(Map<String, dynamic> value) {
    for (final field in ['forge', 'card_refused', 'email', 'predecessor']) {
      if (!value.containsKey(field)) throw FormatException('Core did not answer $field.');
    }
    final agentWord = value['agent'];
    final agent = _agent(agentWord);
    final holds = _bool(value, 'agent_holds_key');
    // Two fields saying different things is an incomplete answer, never the better of the two.
    if (holds != (agent == AgentState.holds)) {
      throw const FormatException('Core answered the agent twice, differently.');
    }
    final registry = value['registry'];
    final pending = value['pending'];
    if (registry is! List || pending is! List) throw const FormatException('Core did not answer registry or pending.');
    return IdentityCard(
      login: _text(value, 'login'),
      name: _text(value, 'name'),
      email: _textOrNull(value, 'email'),
      fingerprint: _fingerprint(_text(value, 'fingerprint')),
      key: _key(_text(value, 'key')),
      created: _text(value, 'created'),
      expires: _text(value, 'expires'),
      predecessor: _textOrNull(value, 'predecessor'),
      card: _text(value, 'card'),
      agent: agent,
      agentWord: agentWord as String,
      revoked: _bool(value, 'revoked'),
      cardRefused: _textOrNull(value, 'card_refused'),
      registry: List.unmodifiable(registry.map(_registry)),
      forge: _forge(value['forge']),
      pending: List.unmodifiable(
        pending.map((operation) {
          if (operation is! Map<String, dynamic>) throw const FormatException('Invalid pending operation.');
          return PendingIdentityOperation(id: _id(_text(operation, 'id')), action: _text(operation, 'action'));
        }),
      ),
    );
  }

  static IdentityRegistry _registry(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid registry entry.');
    final mayFile = _bool(value, 'may_file');
    final whoMay = _contacts(value['who_may']);
    if (!value.containsKey('revision')) throw const FormatException('Core did not answer revision.');
    final revision = value['revision'];
    if (revision != null && revision is! String) throw const FormatException('Invalid registry revision.');
    final filedWord = _text(value, 'filed');
    final filed = _filed(filedWord);
    return IdentityRegistry(
      address: _text(value, 'address'),
      filed: filed,
      filedWord: filedWord,
      revision: revision as String?,
      mayFile: mayFile,
      whoMay: whoMay,
      why: filed == FiledState.refused ? _text(value, 'why') : null,
    );
  }

  static PublishedPlace _publishedPlace(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid published place.');
    final where = _text(value, 'where');
    final name = switch (where) {
      'registry' => _text(value, 'address'),
      'project' => _text(value, 'project'),
      'host' => _text(value, 'host'),
      _ => where,
    };
    final statusWord = _text(value, 'status');
    final status = _place(statusWord);
    final why = _textOrNull(value, 'why');
    if (status == PlaceState.refused && why == null) throw const FormatException('A refused place names no reason.');
    return PublishedPlace(
      where: where,
      name: name,
      status: status,
      statusWord: statusWord,
      why: why,
      whoMay: _contacts(value['who_may']),
    );
  }

  static IdentityOperation _operation(Map<String, dynamic> value) {
    final published = value['published'];
    if (published is! List) throw const FormatException('Core did not answer the published places.');
    return IdentityOperation(
      id: _id(_text(value, 'id')),
      action: _text(value, 'action'),
      fingerprint: _fingerprint(_text(value, 'fingerprint')),
      predecessor: _fingerprint(_text(value, 'predecessor')),
      published: List.unmodifiable(published.map(_publishedPlace)),
    );
  }

  static AgentKey _agentKey(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid agent key.');
    final usable = _bool(value, 'usable');
    final reason = value['reason'];
    if (reason != null && reason is! String) throw const FormatException('Invalid key reason.');
    // An unusable key without a reason, or a usable one with one, is an incomplete answer.
    if (usable == (reason != null)) throw const FormatException('Core answered a key verdict without its reason.');
    if (!value.containsKey('comment')) throw const FormatException('Core did not answer comment.');
    final comment = value['comment'];
    if (comment != null && comment is! String) throw const FormatException('Invalid key comment.');
    return AgentKey(
      fingerprint: _fingerprint(_text(value, 'fingerprint')),
      key: _text(value, 'key'),
      comment: (comment as String?) ?? '',
      usable: usable,
      reason: reason as String?,
      login: value['login'] is String ? value['login'] as String : null,
      keyListed: _boolOrNull(value, 'key_listed'),
    );
  }
}

/// The person's identity as this interface holds it while the view is open.
///
/// **A change starts once**: an operation whose answer was lost is retried by its ID, never started again.
class IdentityModel extends ChangeNotifier {
  /// Constructor taking Core's verbs and the agent's key list, fakes in tests.
  IdentityModel(this.core, {AgentKeyList? keys, this.checkoutFor, Map<String, String>? environment})
    : agentKeys = keys ?? core,
      environment = environment ?? Platform.environment;

  /// The local checkout folder of the registry at an address, or null when none is here.
  final String? Function(String address)? checkoutFor;

  /// Where `XDG_CONFIG_HOME` and `HOME` are read, for the card's file.
  final Map<String, String> environment;

  /// Core's identity verbs.
  final Identity core;

  /// Where "use my existing key" reads its keys from.
  final AgentKeyList agentKeys;

  /// The card last read, absent before the first read or when none is kept.
  IdentityCard? card;

  /// Whether Core said no card is kept: the first start.
  bool firstStart = false;

  /// What went wrong last, in words; never cleared into a good state by itself.
  String? problem;

  /// Core's typed reason for [problem], when it gave one.
  String? problemReason;

  /// Whether a call is running.
  bool busy = false;

  /// The operation shown, from the last answer.
  IdentityOperation? operation;

  /// An operation started whose answer was not read; Retry and read-back use its ID.
  String? unfinishedId;

  /// The lost-key plan awaiting confirmation, with the new key (an agent's or KeePassXC's) and ID it was made for.
  ({LostKeyPlan plan, String? fingerprint, String? database, String? entry, String id})? lostKeyPlan;

  /// Core's exit code for [problem], when a call ended with one.
  int? problemCode;

  /// The commit of the card filed last.
  CardFiled? lastFiled;

  // A filing whose answer was lost, kept per registry so a Retry sends the same ID on the same base.
  final _filing = <String, ({String id, String base})>{};

  /// The agent's keys, once read.
  List<AgentKey>? keys;

  Future<T?> _step<T>(Future<T> Function() call) async {
    busy = true;
    problem = null;
    problemReason = null;
    problemCode = null;
    notifyListeners();
    try {
      return await call();
    } on NoIdentity {
      card = null;
      firstStart = true;
      problem = null;
      problemReason = 'no-identity';
      return null;
    } on IdentityRefused catch (error) {
      problem = error.toString();
      problemReason = error.reason;
      problemCode = error.code;
      return null;
    } on FormatException {
      problem = 'Core gave an answer this interface cannot read. Nothing is assumed from it.';
      return null;
    } on Exception {
      problem = 'Core could not be run.';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Reads the card again; an unreadable answer keeps nothing old as if it were current.
  Future<void> load() async {
    final read = await _step(core.show);
    if (read != null) {
      card = read;
      firstStart = false;
    } else if (problem != null) {
      card = null;
    }
    notifyListeners();
  }

  /// Reads the agent's keys for "use my existing key".
  Future<void> readKeys() async {
    keys = null;
    final read = await _step(agentKeys.keys);
    keys = read;
    notifyListeners();
  }

  /// Makes the card for an existing usable key.
  Future<void> useExistingKey({
    required String login,
    required String name,
    String? email,
    required AgentKey key,
  }) async {
    if (!key.usable) return;
    final made = await _step(
      () => core.createWithKey(login: login, name: name, email: email, fingerprint: key.fingerprint),
    );
    if (made != null) await load();
  }

  /// Why "change my key" cannot be offered now, or null when it can.
  String? get whyNotChange {
    final read = card;
    if (read == null) return 'No card is read.';
    if (busy) return 'Still working.';
    if (unfinishedId != null) return 'An earlier change has not answered. Retry it first.';
    // An interrupted change is finished by its own ID; a second one would make a second key.
    if (read.pending.isNotEmpty) return 'A change is still pending. Retry it or read it back first.';
    return read.whyKeyUnusable;
  }

  /// Changes the key to [successor] once; a lost answer leaves only Retry.
  Future<void> rotate(AgentKey successor) async {
    if (whyNotChange != null || !successor.usable) return;
    final id = newOperationId('rot');
    unfinishedId = id;
    await _runOperation(() => core.rotate(fingerprint: successor.fingerprint, id: id), id);
  }

  /// Marks [id] as a change whose answer a terminal holds, so only Retry and read-back follow.
  void startedInTerminal(String id) {
    unfinishedId = id;
    notifyListeners();
  }

  /// Sends the places of [id] not done, never a second change.
  Future<void> retry(String id) => _runOperation(() => core.publish(id), id);

  /// Reads [id] back, changing nothing.
  Future<void> readBack(String id) => _runOperation(() => core.status(id), id);

  Future<void> _runOperation(Future<IdentityOperation> Function() call, String id) async {
    try {
      final answer = await _step(call);
      if (answer != null) {
        // An answer for another operation is not this one's.
        if (answer.id != id) {
          problem = 'Core answered for operation ${answer.id}, not $id. Nothing is assumed from it.';
          return;
        }
        operation = answer;
        unfinishedId = null;
      } else if (nothingMade.contains(problemReason)) {
        // A typed refusal before anything was made: no operation exists under this ID.
        if (operation?.id != id) unfinishedId = null;
      }
    } finally {
      notifyListeners();
    }
  }

  /// Takes what a terminal running create or rotate ended with, reading Core back and never running it again.
  ///
  /// [id] is the rotation's ID, absent for create; [lastLine] is the terminal's last line, Core's JSON when it fits.
  Future<void> terminalEnded({required int code, required String lastLine, String? id}) async {
    final typed = code == 0 ? null : Identity.typedRefusal(lastLine);
    if (id != null) {
      if (typed != null && nothingMade.contains(typed.reason)) {
        unfinishedId = null;
        problem = typed.words;
        problemReason = typed.reason;
        notifyListeners();
        return;
      }
      await readBack(id);
      return;
    }
    await load();
    if (code != 0 && card == null && problem == null) {
      problem = typed?.words ?? 'Making the key ended with exit $code. The terminal says why.';
      problemReason = typed?.reason;
      notifyListeners();
    }
  }

  /// Shows what replacing a lost key by [successor] would do, before any confirmation.
  Future<void> planLostKey(AgentKey successor) async {
    lostKeyPlan = null;
    if (!successor.usable || unfinishedId != null) return;
    final plan = await _step(() => core.planLostKey(fingerprint: successor.fingerprint));
    if (plan != null) {
      lostKeyPlan = (
        plan: plan,
        fingerprint: successor.fingerprint,
        database: null,
        entry: null,
        id: newOperationId('lost'),
      );
    }
    notifyListeners();
  }

  /// Shows what replacing a lost key by a new one in KeePassXC [database] would do, before any confirmation.
  Future<void> planLostKeyInKeepassxc({required String database, String? entry}) async {
    lostKeyPlan = null;
    if (unfinishedId != null) return;
    final plan = await _step(() => core.planLostKey(database: database, entry: entry));
    if (plan != null) {
      lostKeyPlan = (plan: plan, fingerprint: null, database: database, entry: entry, id: newOperationId('lost'));
    }
    notifyListeners();
  }

  /// Takes the reviewed KeePassXC plan once and answers the command its terminal runs; null when none waits.
  ///
  /// The ID is kept before the terminal opens, so afterwards only [terminalEnded] reads it back.
  ({List<String> command, String id})? confirmLostKeyInTerminal() {
    final reviewed = lostKeyPlan;
    final database = reviewed?.database;
    if (reviewed == null || database == null || unfinishedId != null) return null;
    final command = Identity.replaceLostKeyInKeepassxc(database: database, entry: reviewed.entry, id: reviewed.id);
    lostKeyPlan = null;
    startedInTerminal(reviewed.id);
    return (command: command, id: reviewed.id);
  }

  /// Drops the plan without any call.
  void cancelLostKey() {
    lostKeyPlan = null;
    notifyListeners();
  }

  /// Runs the reviewed plan once, under the ID chosen when it was shown.
  Future<void> confirmLostKey() async {
    final reviewed = lostKeyPlan;
    final fingerprint = reviewed?.fingerprint;
    if (reviewed == null || fingerprint == null || unfinishedId != null) return;
    lostKeyPlan = null;
    unfinishedId = reviewed.id;
    await _runOperation(() => core.replaceLostKey(fingerprint: fingerprint, id: reviewed.id), reviewed.id);
  }

  /// Whether a filing in [registry] lost its answer, so its button retries the same request.
  bool filingUnanswered(IdentityRegistry registry) => _filing.containsKey(registry.address);

  /// Why the card cannot be filed in [registry] now, or null when it can.
  String? whyNotFile(IdentityRegistry registry) {
    if (busy) return 'Still working.';
    if (!registry.mayFile) return 'Only an owner may file it here.';
    if (_filing.containsKey(registry.address)) return null;
    if (registry.filed != FiledState.absent && registry.filed != FiledState.refused) return 'It is filed already.';
    if (card?.whyKeyUnusable case final why?) return why;
    if (checkoutFor?.call(registry.address) == null) return 'No checkout of this registry is on this computer.';
    final revision = registry.revision;
    if (revision == null) return 'Core named no registry revision to file against.';
    try {
      checkedRegistryRevision(revision);
    } on FormatException {
      return 'Core named no full registry revision to file against.';
    }
    return null;
  }

  /// Files the card once; a lost answer keeps the request, a refusal reads again and asks again.
  Future<void> fileCard(IdentityRegistry registry) async {
    if (whyNotFile(registry) != null) return;
    final checkout = checkoutFor?.call(registry.address);
    if (checkout == null) return;
    final request = _filing[registry.address] ?? (id: newOperationId('card'), base: registry.revision!);
    _filing[registry.address] = request;
    final filed = await _step(
      () => core.fileCard(checkout: checkout, card: Identity.cardFile(environment), id: request.id, base: request.base),
    );
    if (filed != null) {
      _filing.remove(registry.address);
      lastFiled = filed;
      await load();
      return;
    }
    if (problemCode == 65) {
      // Refused, a base conflict too: nothing was filed under this request, so the next one is a new decision.
      _filing.remove(registry.address);
      final words = problem;
      await load();
      problem = '$words Check your card here again and file it again if it is still missing.';
      notifyListeners();
    }
  }
}
