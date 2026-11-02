import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

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

/// How the organization holds the person's card.
enum FiledState {
  /// The organization's accepted card is this card.
  done,

  /// Filed and not yet accepted.
  pending,

  /// The organization refused it.
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

/// The organization this machine reads and how it holds the person's card.
@immutable
class IdentityOrganization {
  /// Constructor taking every field Core answers.
  const IdentityOrganization({
    required this.address,
    required this.filed,
    required this.filedWord,
    required this.revision,
    required this.mayFile,
    required this.whoMay,
    this.why,
  });

  /// Where the organization is kept, as Core answers it.
  final String address;

  /// How it holds the card.
  final FiledState filed;

  /// Core's own word, shown when [filed] is unknown.
  final String filedWord;

  /// The organization's revision read, absent when Core names none.
  final String? revision;

  /// Whether the person's own key may file the card here.
  final bool mayFile;

  /// The owners who may file it when [mayFile] is false.
  final List<PersonContact> whoMay;

  /// Why the organization refused it, when it did.
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
  /// Constructor taking the operation's ID and action, and the new key where Core names one.
  const PendingIdentityOperation({required this.id, required this.action, this.fingerprint});

  /// The caller's or Core's operation ID.
  final String id;

  /// `rotate` or `revoke-lost`, or a word this interface does not know.
  final String action;

  /// The new key's fingerprint, the one a Try again names; absent when Core named none that can be named.
  final String? fingerprint;
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
    required this.organization,
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

  /// Whether the key is revoked here or by the organization.
  final bool revoked;

  /// Why the card does not verify, absent when it does.
  final String? cardRefused;

  /// The organization this machine reads, as its one entry; empty where it reads none.
  final List<IdentityOrganization> organization;

  /// The organization's revision read, the base of a change of key; null where none was accepted yet.
  String? get revision => organization.firstOrNull?.revision;

  /// The forge listing, absent when no organization is read.
  final ForgeKeyListing? forge;

  /// Operations started and not finished.
  final List<PendingIdentityOperation> pending;

  /// Why this card can sign nothing whatever the agent serves, or null when it can.
  String? get whyCardCannotSign {
    if (revoked) return 'Your key is revoked. Only “Replace a lost key…” on the Organization page makes a new one now.';
    if (cardRefused case final why?) return 'Your card does not verify: $why';
    return null;
  }

  /// Why nothing that needs this card's key may be offered now, or null when it may.
  String? get whyKeyUnusable {
    if (whyCardCannotSign case final why?) return why;
    return switch (agent) {
      AgentState.holds => null,
      AgentState.notHeld => 'Your SSH agent does not hold your key. Open KeePassXC and load the entry.',
      AgentState.absent => 'No SSH agent is reachable. Start KeePassXC with its SSH agent integration.',
      AgentState.unknown => 'Core answered “$agentWord” for your SSH agent, which this interface does not know.',
    };
  }
}

/// One place a lost key's replacement reaches.
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

  /// `organization`, `project`, `host`, or a word this interface does not know.
  final String where;

  /// The organization's address, the project's or the host's name.
  final String name;

  /// Where the place stands.
  final PlaceState status;

  /// Core's own word, shown when [status] is unknown.
  final String statusWord;

  /// Why it waits or was refused.
  final String? why;

  /// Who must accept it.
  final List<PersonContact> whoMay;
}

/// The answer of `identity rotate` and `identity revoke --lost`, as every write answers.
@immutable
class IdentityOperation {
  /// Constructor taking what Core answered and the action asked for.
  const IdentityOperation({
    required this.id,
    required this.action,
    required this.revision,
    required this.again,
    this.card,
  });

  /// The operation's ID, the one a Retry sends.
  final String id;

  /// `rotate` or `revoke-lost`.
  final String action;

  /// The revision it rests on; null when nothing was accepted yet.
  final String? revision;

  /// Whether this ID had already made the change.
  final bool again;

  /// A lost key's new card, to hand to an owner outside Porelo; absent when Core answered none.
  final String? card;
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

  /// The forge listing, absent when no organization is read.
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

  /// Whether the forge lists it; null without an organization read or a listing.
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

/// The agent's keys, read through a small seam so a test can stand in.
abstract interface class AgentKeyList {
  /// The keys the agent serves, in its order; throws [IdentityRefused] with `agent-absent` when none answers.
  Future<List<AgentKey>> keys();
}

/// Core refused or could not answer; carries its typed reason when it gave one.
class IdentityRefused implements Exception {
  /// Constructor taking the exit code, the typed reason and Core's words.
  const IdentityRefused(
    this.words, {
    required this.code,
    this.reason,
    this.login,
    this.whoMay = const <PersonContact>[],
  });

  /// Why, in a sentence safe to show.
  final String words;

  /// The people who may make this change.
  final List<PersonContact> whoMay;

  /// The exit code Core ended with.
  final int code;

  /// Core's fixed kebab-case reason, absent when it named none.
  final String? reason;

  /// The other login of `key-on-another-card`.
  final String? login;

  @override
  String toString() {
    final contacts = whoMay
        .map((person) => '${person.name} (${person.login})${person.email == null ? '' : ', ${person.email}'}')
        .join('; ');
    return '$words${contacts.isEmpty ? '' : ' Ask $contacts.'}';
  }
}

/// A person named as one who may make a change.
class PersonContact {
  /// Constructor taking the login, the name and the card's address.
  const PersonContact({required this.login, required this.name, this.email});

  /// Their login.
  final String login;

  /// Their name on their card.
  final String name;

  /// Their card's address, absent when the card has none.
  final String? email;
}

/// The person has no card yet: the first start.
class NoIdentity implements Exception {
  /// Constructor taking Core's words.
  const NoIdentity(this.words);

  /// Core's words, for a person.
  final String words;
}

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
      agent: _knownAgent(answer['agent']),
      forge: _forge(_field(answer, 'forge')),
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

  /// Changes the key to [fingerprint], an existing key the agent serves, under operation [id] against [base].
  Future<IdentityOperation> rotate({required String fingerprint, required String id, String? base}) async => _operation(
    await _call(['identity', 'rotate', '--key', _fingerprint(fingerprint), ..._write(id, base), '--json']),
    'rotate',
  );

  /// The command a terminal runs to change the key to a new one in KeePassXC under operation [id] against [base].
  static List<String> rotateInKeepassxc({required String database, String? entry, required String id, String? base}) =>
      ['porelo', 'identity', 'rotate', ..._keepassxc(database, entry), ..._write(id, base), '--json'];

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

  /// Replaces a lost key by [fingerprint] under operation [id] against [base], after the plan was confirmed.
  Future<IdentityOperation> replaceLostKey({required String fingerprint, required String id, String? base}) async =>
      _operation(
        await _call([
          'identity',
          'revoke',
          '--lost',
          '--key',
          _fingerprint(fingerprint),
          ..._write(id, base),
          '--json',
        ]),
        'revoke-lost',
      );

  /// The command a terminal runs to replace a lost key by a new one in KeePassXC under operation [id] against [base].
  static List<String> replaceLostKeyInKeepassxc({
    required String database,
    String? entry,
    required String id,
    String? base,
  }) => ['porelo', 'identity', 'revoke', '--lost', ..._keepassxc(database, entry), ..._write(id, base), '--json'];

  /// Reads what a terminal running operation [id] of [action] ended with; refuses an unreadable answer or another's.
  static IdentityOperation terminalAnswer(String lastLine, {required String id, required String action}) {
    final answer = _operation(_object(lastLine.trim()), action);
    if (answer.id != id) throw FormatException('Core answered for operation ${answer.id}, not $id.');
    return answer;
  }

  /// Where Core keeps the person's card: `$XDG_CONFIG_HOME/porelo/identity/card`.
  static String cardFile(Map<String, String> environment) {
    final config = environment['XDG_CONFIG_HOME'];
    final base = config != null && config.isNotEmpty ? config : '${environment['HOME'] ?? ''}/.config';
    return '$base/porelo/identity/card';
  }

  // A write names its revision, except where nothing was accepted yet.
  static List<String> _write(String id, String? base) => [
    if (base != null) ...['--base', base],
    '--id',
    _id(id),
  ];

  static List<String> _successor(String? fingerprint, String? database, String? entry) {
    if ((fingerprint == null) == (database == null)) throw const FormatException('Name exactly one new key.');
    return fingerprint != null ? ['--key', _fingerprint(fingerprint)] : _keepassxc(database!, entry);
  }

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
    final Object? value;
    try {
      value = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Core gave an answer this interface cannot read.');
    }
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

  static Object? _field(Map<String, dynamic> value, String field) {
    if (!value.containsKey(field)) throw FormatException('Core did not answer $field.');
    return value[field];
  }

  // A made card's agent word must be one this interface knows; an unknown one is an incomplete answer.
  static AgentState _knownAgent(Object? word) {
    final agent = _agent(word);
    if (agent == AgentState.unknown) {
      throw const FormatException('Core answered an agent word this interface does not know.');
    }
    return agent;
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

  // A row whose key cannot be named stays readable: it only offers no Try again.
  static String? _nameableKey(Object? value) {
    if (value is! String) return null;
    try {
      return _fingerprint(value);
    } on FormatException {
      return null;
    }
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

  static List<PersonContact> _contacts(Object? value) {
    if (value is! List) throw const FormatException('Core did not answer who may.');
    return List.unmodifiable(
      value.map((contact) {
        if (contact is! Map<String, dynamic>) throw const FormatException('Invalid contact.');
        final login = _text(contact, 'login');
        // Core names a contact without an accepted card with `name` and `email` null; it is named by its login.
        if (!contact.containsKey('name')) throw const FormatException('Core did not answer name.');
        return PersonContact(
          login: login,
          name: contact['name'] == null ? login : _text(contact, 'name'),
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
    final organization = value['organization'];
    final pending = value['pending'];
    if (organization is! List) throw const FormatException('Core answered no organization for your card.');
    if (pending is! List) throw const FormatException('Core did not answer pending.');
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
      organization: List.unmodifiable(organization.map(_organization)),
      forge: _forge(value['forge']),
      pending: List.unmodifiable(
        pending.map((operation) {
          if (operation is! Map<String, dynamic>) throw const FormatException('Invalid pending operation.');
          return PendingIdentityOperation(
            id: _id(_text(operation, 'id')),
            action: _text(operation, 'action'),
            fingerprint: _nameableKey(operation['fingerprint']),
          );
        }),
      ),
    );
  }

  static IdentityOrganization _organization(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Core answered an organization it cannot name.');
    final mayFile = _bool(value, 'may_file');
    final whoMay = _contacts(value['who_may']);
    if (!value.containsKey('revision')) throw const FormatException('Core did not answer revision.');
    final revision = value['revision'];
    if (revision != null && revision is! String) throw const FormatException('Invalid organization revision.');
    final filedWord = _text(value, 'filed');
    final filed = _filed(filedWord);
    return IdentityOrganization(
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
      'organization' => _text(value, 'address'),
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

  static IdentityOperation _operation(Map<String, dynamic> value, String action) {
    final revision = value['revision'];
    final again = value['again'];
    if (revision != null && revision is! String) {
      throw const FormatException('Core answered revision in another shape.');
    }
    final card = value['card'];
    return IdentityOperation(
      id: _id(_text(value, 'id')),
      action: action,
      revision: revision as String?,
      again: again == true,
      card: action == 'revoke-lost' && card is String && card.trim().isNotEmpty ? card : null,
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
      // A usable key must be the Ed25519 key it claims to be; an unusable one is shown as Core names it.
      key: usable ? _key(_text(value, 'key')) : _text(value, 'key'),
      comment: (comment as String?) ?? '',
      usable: usable,
      reason: reason as String?,
      login: value['login'] is String ? value['login'] as String : null,
      keyListed: _boolOrNull(value, 'key_listed'),
    );
  }
}

/// Whether a write that ended with exit [code] may have been made, so its id is kept: 69, 70, or a process that was
/// killed, which a terminal reports as absent, negative or above 128. Every other refusal made nothing.
bool mayHaveMade(int? code) => code == null || code < 0 || code > 128 || code == 69 || code == 70;

/// The person's identity as this interface holds it while the view is open.
///
/// **A change starts once**: an operation whose answer was lost is asked again under its ID, never started anew.
class IdentityModel extends ChangeNotifier {
  /// Constructor taking Core's verbs and the agent's key list, fakes in tests.
  IdentityModel(this.core, {AgentKeyList? keys}) : agentKeys = keys ?? core;

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

  /// An operation started whose answer was not read; Retry asks it again under this ID.
  String? unfinishedId;

  /// The action of [unfinishedId]: `rotate` or `revoke-lost`.
  String? unfinishedAction;

  /// The command a terminal runs again for [unfinishedId], when it was started in one.
  List<String>? unfinishedCommand;

  // How [unfinishedId] is asked again here, when it was not started in a terminal.
  Future<IdentityOperation> Function()? _again;

  /// The plan a lost key's new card was made after, for its words; absent when none was read in this window.
  LostKeyPlan? handoverPlan;

  /// The pending change another key is being chosen for; only it is passed over while the person chooses.
  PendingIdentityOperation? replacing;

  // Rows the organization holds, with Core's words: their first card stands and nothing more is offered.
  final _standing = <String, String>{};

  /// The lost-key plan awaiting confirmation, with the new key (an agent's or KeePassXC's) and ID it was made for.
  ({LostKeyPlan plan, String? fingerprint, String? database, String? entry, String id})? lostKeyPlan;

  /// Core's exit code for [problem], when a call ended with one.
  int? problemCode;

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
    } on FormatException catch (error) {
      problem = '${error.message} Nothing is assumed from this answer.';
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

  /// Why no new change of key (rotate or lost-key replacement) may start now, or null when one may.
  ///
  /// An unfinished operation, here or in Core's pending list, comes first; a second one would make a second key.
  String? get whyNotStart {
    final read = card;
    if (read == null) return 'No card is read.';
    if (busy) return 'Still working.';
    if (unfinishedId != null) return 'An earlier change has not answered. Retry it first.';
    if (read.pending.any((row) => row.id != replacing?.id)) {
      return 'A change is still pending: try it again or use another key where it is listed.';
    }
    return null;
  }

  /// Why replacing a lost key may not start now, or null when it may. Porelo files nothing for it, and it replaces a
  /// pending rotation, whose key may be the one that was lost, so only a replacement already pending holds it up.
  String? get whyNotLostKey {
    final read = card;
    if (read == null) return 'No card is read.';
    if (busy) return 'Still working.';
    if (unfinishedId != null) return 'An earlier change has not answered. Retry it first.';
    if (read.pending.any((row) => row.action != 'rotate' && row.id != replacing?.id)) {
      return 'A change is still pending: try it again or use another key where it is listed.';
    }
    return null;
  }

  /// Why "change my key" cannot be offered now, or null when it can: it also needs the current key.
  ///
  /// A pending change being replaced is the way out when the agent no longer serves a key, so Core decides that one.
  String? get whyNotChange => whyNotStart ?? (replacing == null ? card?.whyKeyUnusable : card?.whyCardCannotSign);

  /// Core's words for a row whose change the organization already holds, or null while it offers something.
  String? standing(PendingIdentityOperation row) => _standing[row.id];

  String? _whyNoOffer(PendingIdentityOperation row) {
    final read = card;
    if (read == null) return 'No card is read.';
    if (busy) return 'Still working.';
    if (unfinishedId != null) return 'An earlier change has not answered. Retry it first.';
    if (_standing[row.id] case final words?) return words;
    return switch (row.action) {
      'rotate' => read.whyCardCannotSign,
      // Replacing a lost key needs nothing of the old one.
      'revoke-lost' => null,
      final word => 'Core calls this change “$word”, which this interface does not know, so nothing is offered for it.',
    };
  }

  /// Why [row] cannot be tried again now, or null when it can: only with the key Core names for it.
  String? whyNotTryAgain(PendingIdentityOperation row) {
    if (_whyNoOffer(row) case final why?) return why;
    if (row.fingerprint == null) {
      return 'Core names no key for this change, so it cannot be asked again. Use another key starts it again.';
    }
    return null;
  }

  /// Why another key cannot be chosen for [row] now, or null when it can.
  String? whyNotReplace(PendingIdentityOperation row) => _whyNoOffer(row);

  /// Goes on with [row] under its own ID and key, whatever the attempt before answered: never a second change.
  Future<void> tryAgain(PendingIdentityOperation row) async {
    final fingerprint = row.fingerprint;
    if (whyNotTryAgain(row) != null || fingerprint == null) return;
    replacing = null;
    final id = row.id;
    final base = card?.revision;
    final answer = await _step(
      () => row.action == 'rotate'
          ? core.rotate(fingerprint: fingerprint, id: id, base: base)
          : core.replaceLostKey(fingerprint: fingerprint, id: id, base: base),
    );
    if (answer != null && answer.id != id) {
      problem = 'Core answered for operation ${answer.id}, not $id. Nothing is assumed from it.';
    } else if (answer != null) {
      operation = answer;
    } else if (problemReason == 'exists') {
      _standing[id] = problem ?? 'The organization already holds this change.';
    }
    await _loadKeeping();
  }

  /// Lets the person choose another key for [row]; what runs then takes a new ID, as any new change does.
  void startReplacing(PendingIdentityOperation row) {
    if (whyNotReplace(row) != null) return;
    replacing = row;
    notifyListeners();
  }

  /// Goes back to [replacing] being pending, with no call.
  void stopReplacing() {
    replacing = null;
    notifyListeners();
  }

  // A replacement came to an end: a row the organization holds stays as it stands and offers nothing more.
  void _replacementEnded(String? reason, String? words) {
    final row = replacing;
    replacing = null;
    if (row != null && reason == 'exists') _standing[row.id] = words ?? 'The organization already holds this change.';
  }

  /// Why [successor] cannot replace the current key, or null when it can.
  String? whyNotSuccessor(AgentKey successor, {bool forLostKey = false}) {
    if (!successor.usable) return successor.whyNot;
    if (successor.fingerprint == card?.fingerprint) return 'This is your current key.';
    if (card?.pending.any(
          (row) => row.fingerprint == successor.fingerprint && !(forLostKey && row.action == 'rotate'),
        ) ??
        false) {
      return 'A pending change waits for this key: Try again goes on with it.';
    }
    return null;
  }

  /// Changes the key to [successor] once; a lost answer leaves only Retry.
  Future<void> rotate(AgentKey successor) async {
    if (whyNotChange != null || whyNotSuccessor(successor) != null) return;
    final id = newOperationId('rot');
    final base = card?.revision;
    await _ask(id, 'rotate', () => core.rotate(fingerprint: successor.fingerprint, id: id, base: base));
  }

  /// Takes a rotation to a new KeePassXC key once and answers the command its terminal runs; null when refused.
  ///
  /// The ID is kept before the terminal opens, so afterwards only [terminalEnded] takes it.
  ({List<String> command, String id})? rotateInTerminal({required String database, String? entry}) {
    if (whyNotChange != null) return null;
    final id = newOperationId('rot');
    final List<String> command;
    try {
      command = Identity.rotateInKeepassxc(database: database, entry: entry, id: id, base: card?.revision);
    } on FormatException catch (error) {
      problem = error.message;
      notifyListeners();
      return null;
    }
    _started(id, 'rotate', command: command);
    return (command: command, id: id);
  }

  void _started(String id, String action, {List<String>? command, Future<IdentityOperation> Function()? again}) {
    unfinishedId = id;
    unfinishedAction = action;
    unfinishedCommand = command;
    _again = again;
    notifyListeners();
  }

  void _settled(String id) {
    if (unfinishedId == id) {
      unfinishedId = null;
      unfinishedAction = null;
      unfinishedCommand = null;
      _again = null;
    }
  }

  /// Why the unfinished operation cannot be asked again now, or null when it can; a rotation also needs the current key.
  String? get whyNotRetry {
    if (busy) return 'Still working.';
    if (unfinishedId == null) return 'Nothing is unfinished.';
    if (unfinishedAction != 'rotate') return null;
    final read = card;
    if (read == null) return 'No card is read.';
    return replacing == null ? read.whyKeyUnusable : read.whyCardCannotSign;
  }

  /// Asks the unfinished operation again under its ID, which answers what it did; never a second change.
  Future<void> retry() async {
    final id = unfinishedId;
    final again = _again;
    if (whyNotRetry != null || id == null || again == null) return;
    await _runOperation(again, id);
  }

  Future<void> _ask(String id, String action, Future<IdentityOperation> Function() call) async {
    _started(id, action, again: call);
    await _runOperation(call, id);
  }

  // After 69, 70 or a killed process the change may have been made; every other refusal made nothing.

  Future<void> _runOperation(Future<IdentityOperation> Function() call, String id) async {
    final answer = await _step(call);
    if (answer != null) {
      // An answer for another operation is not this one's.
      if (answer.id != id) {
        problem = 'Core answered for operation ${answer.id}, not $id. Nothing is assumed from it.';
        notifyListeners();
        return;
      }
      operation = answer;
      _settled(id);
      _replacementEnded(null, null);
    } else if (problemReason == 'no-identity' || !mayHaveMade(problemCode)) {
      _settled(id);
      _replacementEnded(problemReason, problem);
    } else {
      return;
    }
    await _loadKeeping();
  }

  // Core's pending list, not this answer, says what is still open; a refusal's words stay beside it.
  Future<void> _loadKeeping() async {
    final words = problem;
    final reason = problemReason;
    await load();
    if (words != null && problem == null) {
      problem = words;
      problemReason = reason;
      notifyListeners();
    }
  }

  /// Why the card read is not the one just made for [login], or null when it is: its key is [fingerprint] (an agent
  /// key picked) and in any case another than [before], the key read before making, and the agent serves it.
  String? whyNotMade({required String login, String? fingerprint, String? before}) {
    final read = card;
    if (read == null) return problem ?? 'No card is read.';
    if (read.login != login) return 'The card read is ${read.login}’s, not one made for $login.';
    if (fingerprint != null && read.fingerprint != fingerprint) {
      return 'The card read names another key than the one picked.';
    }
    if (read.fingerprint == before) return 'The card read is the earlier one, not a new one.';
    return read.whyKeyUnusable;
  }

  /// Takes what a terminal running create or a key change ended with, and never runs it again by itself.
  ///
  /// [id] is the change's ID, absent for create; [lastLine] is the terminal's last line, Core's JSON when it fits.
  Future<void> terminalEnded({required int code, required String lastLine, String? id}) async {
    final typed = code == 0 ? null : Identity.typedRefusal(lastLine);
    if (id != null) return _changeEnded(id, code: code, lastLine: lastLine, words: typed?.words, reason: typed?.reason);
    await load();
    // A failed create is said even when a card is read: it may be an older one, not the one asked for.
    if (code != 0) {
      problem = typed?.words ?? 'Making the key ended with exit $code. The terminal says why.';
      problemReason = typed?.reason;
      notifyListeners();
    }
  }

  Future<void> _changeEnded(
    String id, {
    required int code,
    required String lastLine,
    required String? words,
    required String? reason,
  }) async {
    final action = unfinishedAction ?? 'rotate';
    String? said = words;
    if (code == 0) {
      try {
        operation = Identity.terminalAnswer(lastLine, id: id, action: action);
        _settled(id);
        _replacementEnded(null, null);
      } on FormatException catch (error) {
        said = '${error.message} It may have been made: Retry asks again under the same ID.';
      }
    } else if (mayHaveMade(code)) {
      said =
          '${words ?? 'The terminal ended with no answer read.'} It may have been made: Retry asks again under the '
          'same ID.';
    } else {
      said = words ?? 'It ended with exit $code. The terminal says why.';
      _settled(id);
      _replacementEnded(reason, said);
    }
    await load();
    if (said != null) {
      problem = said;
      problemReason = reason;
      notifyListeners();
    }
  }

  /// Shows what replacing a lost key by [successor] would do, before any confirmation.
  Future<void> planLostKey(AgentKey successor) async {
    lostKeyPlan = null;
    if (whyNotLostKey != null || whyNotSuccessor(successor, forLostKey: true) != null) return;
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
    if (whyNotLostKey != null) return;
    final plan = await _step(() => core.planLostKey(database: database, entry: entry));
    if (plan != null) {
      lostKeyPlan = (plan: plan, fingerprint: null, database: database, entry: entry, id: newOperationId('lost'));
    }
    notifyListeners();
  }

  /// Takes the reviewed KeePassXC plan once and answers the command its terminal runs; null when none waits.
  ///
  /// The ID is kept before the terminal opens, so afterwards only [terminalEnded] takes it.
  ({List<String> command, String id})? confirmLostKeyInTerminal() {
    final reviewed = lostKeyPlan;
    final database = reviewed?.database;
    if (reviewed == null || database == null || whyNotLostKey != null) return null;
    final command = Identity.replaceLostKeyInKeepassxc(
      database: database,
      entry: reviewed.entry,
      id: reviewed.id,
      base: card?.revision,
    );
    lostKeyPlan = null;
    handoverPlan = reviewed.plan;
    _started(reviewed.id, 'revoke-lost', command: command);
    return (command: command, id: reviewed.id);
  }

  /// Drops the plan without any call.
  void cancelLostKey() {
    lostKeyPlan = null;
    replacing = null;
    notifyListeners();
  }

  /// Runs the reviewed plan once, under the ID chosen when it was shown.
  Future<void> confirmLostKey() async {
    final reviewed = lostKeyPlan;
    final fingerprint = reviewed?.fingerprint;
    if (reviewed == null || fingerprint == null || whyNotLostKey != null || fingerprint == card?.fingerprint) return;
    lostKeyPlan = null;
    handoverPlan = reviewed.plan;
    final base = card?.revision;
    await _ask(
      reviewed.id,
      'revoke-lost',
      () => core.replaceLostKey(fingerprint: fingerprint, id: reviewed.id, base: base),
    );
  }

  /// Whether a new card waits here for a lost key: one just replaced, or one Core still lists as pending.
  bool get lostKeyCardMade =>
      operation?.action == 'revoke-lost' || (card?.pending.any((pending) => pending.action == 'revoke-lost') ?? false);
}
