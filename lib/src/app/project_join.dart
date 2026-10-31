import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart';

import 'machines.dart';
import 'registry.dart';
import 'settings.dart';

/// One project and host in which Core's verified state names the person, as Core's discovery answers it.
///
/// Core reads the registry's `hosts/<host>/access.yml`, follows each access repository it names, and answers what it
/// verified. The interface verifies no YAML or signature of its own.
sealed class JoinAdmission {
  const JoinAdmission();
}

/// A verified admission: the person is named in [project]'s access file on [host].
@immutable
class JoinOffered extends JoinAdmission {
  /// Retains Core's verified public values.
  JoinOffered({
    required this.project,
    required this.host,
    required this.login,
    required this.source,
    required this.revision,
    required List<String> signers,
    this.homeserver,
  }) : signers = List.unmodifiable(signers);

  /// The project's name.
  final String project;

  /// The accepted host card.
  final PreparedHost host;

  /// The person's account on [host], Core's `host_account`: a person's host account is their login.
  final String login;

  /// The project repository's address, credential-free.
  final String source;

  /// The project's access commit Core verified as in force.
  final String revision;

  /// The homeserver the verified access file names, or null when it names none.
  final String? homeserver;

  /// The project's signers Core verified, followed with as given.
  final List<String> signers;

  /// The row's identity: one project on one host.
  String get key => '$project@${host.name}';

  /// Refuses an incomplete verdict before anything is followed, written or connected.
  void check() {
    if (!_project.hasMatch(project) ||
        !RegExp(r'^[a-z][a-z0-9-]{0,31}$').hasMatch(login) ||
        !_usable(source) ||
        signers.isEmpty ||
        signers.any((signer) => !RegExp(r'^ssh-ed25519 [A-Za-z0-9+/]{68}$').hasMatch(signer)) ||
        !RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(revision)) {
      throw const RegistryRefusal('Core did not verify this admission completely, so nothing was joined.');
    }
  }

  /// Whether [machine] is the watched account reached through this admission's host card, never a rental record.
  bool reaches(Machine machine) {
    final card = machine.hostCard;
    return machine.kind == 'host' &&
        machine.host == host.name &&
        !machine.legacyHost &&
        machine.identity.isEmpty &&
        card != null &&
        card.login == login &&
        machine.remoteSocket == card.daemonSocket &&
        card.name == host.name &&
        card.address == host.address &&
        card.sshPort == host.sshPort &&
        card.hostKey == host.sshHostKey;
  }

  /// Whether [followed] is the host's verified, in-force follow of this admission, pinned to exactly Core's signers.
  bool confirms(Followed followed) =>
      followed.name == project &&
      followed.url == source &&
      followed.accessCommit == revision &&
      !followed.unverified &&
      followed.signers.length == signers.length &&
      setEquals(followed.signers.toSet(), {for (final signer in signers) _fingerprint(signer)});

  /// Whether [other] is the same verified admission, unchanged.
  bool same(JoinOffered other) =>
      other.key == key &&
      other.login == login &&
      other.source == source &&
      other.revision == revision &&
      other.homeserver == homeserver &&
      listEquals(other.signers, signers) &&
      jsonEncode(other.host.stored) == jsonEncode(host.stored);
}

/// An access repository named for a host whose access file Core could not read.
@immutable
class JoinUnreadable extends JoinAdmission {
  /// Retains the repository and who may grant it.
  const JoinUnreadable({required this.host, required this.repository, this.whoMay = const []});

  /// The host whose access entries name the repository.
  final String host;

  /// The access repository's address, or null when the registry refused the host's own access file.
  final String? repository;

  /// The verified admins who may grant reading it, or the host's admins for its own access file.
  final List<RegistryContact> whoMay;

  /// What the row says.
  String get words => RegistryRefusal(
    repository == null
        ? 'The registry refused the access file of $host, so no project on it is known here.'
        : 'The access file in $repository for $host cannot be read, so its projects are not known here.',
    whoMay: whoMay,
  ).toString();
}

/// A project Core answered for the person in a form this interface cannot use, said as that row's own refusal.
@immutable
class JoinUnusable extends JoinAdmission {
  /// Retains the row and why it cannot be joined here.
  const JoinUnusable({required this.project, required this.host, required this.why, this.whoMay = const []});

  /// The project's name as Core answered it.
  final String project;

  /// The host as Core answered it.
  final String host;

  /// What of the row cannot be used here.
  final String why;

  /// The project's admins Core named.
  final List<RegistryContact> whoMay;

  /// The row's identity: one project on one host.
  String get key => '$project@$host';

  /// What the row says.
  String get words => RegistryRefusal(
    'Core names you in project $project on host $host, but $why, so it cannot be joined from here.',
    whoMay: whoMay,
  ).toString();
}

final _connecting = Expando<Map<String, Future<Machine>>>();
final _pending = Expando<Map<String, Machine>>();
final _additions = Expando<Map<String, Future<void>>>();
final _joining = Expando<Map<String, int>>();

/// A key's `SHA256:` fingerprint, as the daemon names the keys a follow pinned.
String _fingerprint(String key) =>
    'SHA256:${base64Encode(sha256.convert(base64Decode(key.split(' ')[1])).bytes).replaceAll('=', '')}';

/// Core's project name: `[a-z0-9][a-z0-9-]{0,62}`.
final _project = RegExp(r'^[a-z0-9][a-z0-9-]{0,62}$');

/// The ssh user git hands to ssh, never a secret: it cannot start an option.
const _sshUser = r'[A-Za-z0-9][A-Za-z0-9._-]*';

/// A host as a repository address names it, a name or an IPv4 address, or an IPv6 address in brackets for `ssh://`.
const _addressHost = r'[A-Za-z0-9][A-Za-z0-9.-]*';

/// Whether a repository address Core answered carries a credential: a user beside an `https` host, a password or
/// anything beyond an ssh user before the last `@`, or a query that may hold a token.
bool _credential(String address) {
  final scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').matchAsPrefix(address);
  if (scheme == null) {
    final at = address.lastIndexOf('@');
    return at >= 0 && !RegExp('^$_sshUser\$').hasMatch(address.substring(0, at));
  }
  final rest = address.substring(scheme.end);
  final end = rest.indexOf(RegExp('[/?#]'));
  final authority = end < 0 ? rest : rest.substring(0, end);
  final at = authority.lastIndexOf('@');
  final ssh = scheme.group(0)!.toLowerCase() == 'ssh://';
  return address.contains('?') || (at >= 0 && (!ssh || !RegExp('^$_sshUser\$').hasMatch(authority.substring(0, at))));
}

/// Whether a credential-free repository address is in a form this interface follows: `https://host/path`,
/// `ssh://[user@]host[:port]/path` or `user@host:path`.
bool _usable(String address) {
  if (_credential(address) || RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(address)) return false;
  const path = r'[A-Za-z0-9_.~+-][A-Za-z0-9_./~+-]*';
  if (RegExp('^ssh://($_sshUser@)?($_addressHost|\\[[0-9A-Fa-f:]+\\])(:[0-9]{1,5})?/$path\$').hasMatch(address) ||
      RegExp('^$_sshUser@$_addressHost:$path\$').hasMatch(address)) {
    return true;
  }
  final uri = Uri.tryParse(address);
  return uri != null &&
      uri.scheme == 'https' &&
      address.startsWith('https://') &&
      RegExp('^$_addressHost\$').hasMatch(uri.host) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.length > 1;
}

/// Reads the answer of `porelo registry joinable --login [login] --json`, or refuses it whole so it never shows as an
/// empty list.
///
/// A row for another login than [login], a host card for another host than its row, or an address with a credential
/// refuses the answer whole. A row Core admitted in a form this interface cannot use is that row's own refusal. A
/// project Core refused is never offered, even when the same answer also lists it as admitted.
List<JoinAdmission> readJoinable(Object? json, {required String login}) {
  try {
    if (json is! Map<String, Object?>) throw const FormatException('not an object');
    final projects = json['projects'];
    final refused = json['refused'];
    if (projects is! List || refused is! List) throw const FormatException('no projects or refused');
    final closed = <String>{};
    final closedHosts = <String>{};
    final unreadable = <String, JoinUnreadable>{};
    for (final entry in refused) {
      final (key, row) = _unreadable(_object(entry));
      if (key == null) {
        closedHosts.add(row.host);
      } else {
        closed.add(key);
      }
      // One row per repository and host, as several refused projects may share one access repository.
      final same = unreadable['${row.repository} ${row.host}'];
      unreadable['${row.repository} ${row.host}'] = same == null
          ? row
          : JoinUnreadable(
              host: row.host,
              repository: row.repository,
              whoMay: [
                ...same.whoMay,
                for (final admin in row.whoMay)
                  if (!same.whoMay.any((each) => each.login == admin.login)) admin,
              ],
            );
    }
    final offered = <String, JoinAdmission>{};
    for (final entry in projects) {
      final (key, row) = _offered(_object(entry), login);
      if (offered.containsKey(key)) throw const FormatException('a project twice');
      offered[key] = row;
    }
    return [
      for (final MapEntry(:key, value: row) in offered.entries)
        if (!closed.contains(key) && !closedHosts.contains(key.substring(key.indexOf('@') + 1))) row,
      ...unreadable.values,
    ];
  } on Object catch (error) {
    if (error is RegistryRefusal) rethrow;
    throw const RegistryRefusal('Core\'s answer on the projects you may join could not be read.');
  }
}

Map<String, Object?> _object(Object? entry) =>
    entry is Map<String, Object?> ? entry : throw const FormatException('not an object');

/// A refused project's key and row; a host whose own access file the registry refused has no key, as all its
/// projects are closed.
(String?, JoinUnreadable) _unreadable(Map<String, Object?> entry) {
  final host = _text(entry, 'host');
  _text(entry, 'why');
  final ofTheHost = entry['project'] == null;
  if (ofTheHost != (entry['access_repository'] == null)) throw const FormatException('half a host row');
  return (
    ofTheHost ? null : '${_text(entry, 'project')}@$host',
    JoinUnreadable(
      host: host,
      repository: ofTheHost ? null : _checked(_text(entry, 'access_repository')),
      whoMay: _contacts(entry['admins']),
    ),
  );
}

/// One admitted row's key and what it shows: the offer, or its own refusal when Core answered it in a form this
/// interface cannot use.
(String, JoinAdmission) _offered(Map<String, Object?> entry, String login) {
  final card = entry['host_card'];
  if (card is! Map<String, Object?>) throw const FormatException('no host card');
  final name = _text(entry, 'host');
  // Core names the card's host under `host`; a card of another host is never taken for this row's.
  if (card['host'] != name) throw const FormatException('the host card names another host');
  if (_text(entry, 'host_account') != login) throw const FormatException('a row for another login');
  if (!entry.containsKey('homeserver')) throw const FormatException('no homeserver');
  final homeserver = entry['homeserver'] == null ? null : _text(entry, 'homeserver');
  final project = _text(entry, 'project');
  final source = _text(entry, 'source');
  final access = _text(entry, 'access_repository');
  if (_credential(source) || _credential(access)) throw const FormatException('an address with credentials');
  final admins = _contacts(entry['admins']);
  if (admins.isEmpty) throw const FormatException('nobody may grant it');
  final signers = entry['signers'];
  if (signers is! List) throw const FormatException('no signers');
  final key = '$project@$name';
  JoinUnusable unusable(String why) => JoinUnusable(project: project, host: name, why: why, whoMay: admins);
  if (!_project.hasMatch(project)) return (key, unusable('its project name is not one a project takes'));
  if (!_usable(source)) return (key, unusable('its project repository address is in a form not followed here'));
  if (!_usable(access)) return (key, unusable('its access repository address is in a form not read here'));
  final PreparedHost host;
  try {
    host = PreparedHost.card(card);
  } on FormatException {
    return (key, unusable('the host card gives an address or port this interface cannot reach'));
  }
  return (
    key,
    JoinOffered(
      project: project,
      host: host,
      login: login,
      source: source,
      revision: _text(entry, 'revision'),
      signers: signers.cast<String>(),
      homeserver: homeserver,
    )..check(),
  );
}

String _checked(String repository) =>
    _credential(repository) ? throw const FormatException('an access repository with credentials') : repository;

String _text(Map<String, Object?> entry, String key) {
  final value = entry[key];
  if (value is! String || value.trim().isEmpty) throw FormatException('no $key');
  return value;
}

/// Core's contacts, each `{"login", "name", "email"}`: `name` and `email` null without an accepted card, `email` null
/// when the card has none. A contact without a name is named by its login.
List<RegistryContact> _contacts(Object? json) {
  if (json is! List) throw const FormatException('no admins');
  final contacts = <RegistryContact>[];
  for (final admin in json.map(_object)) {
    final email = admin['email'];
    if (!admin.containsKey('email') || (email != null && email is! String)) throw const FormatException('no email');
    if (!admin.containsKey('name')) throw const FormatException('no name');
    final login = _text(admin, 'login');
    final name = admin['name'] == null ? login : _text(admin, 'name');
    contacts.add(RegistryContact(login: login, name: name, email: email as String?));
  }
  return contacts;
}

/// Core's verified discovery of where the person is admitted. Assumed until Core serves it.
abstract interface class JoinDiscovery {
  /// Every admission Core verified for the current person, and every access repository it could not read.
  Future<List<JoinAdmission>> admissions();
}

/// The host side of joining: the card tunnel and the account daemon's follow.
abstract interface class JoinHost {
  /// Opens, or reuses, the one tunnel to [offer]'s host as its login through the person's agent, and names the
  /// watched account.
  Future<Machine> connect(JoinOffered offer);

  /// What the account daemon follows as [project], or null when it follows nothing by that name.
  Future<Followed?> followed(Machine machine, String project);

  /// Follows [offer] on the account daemon with Core's signers, never unverified.
  Future<Followed> follow(Machine machine, JoinOffered offer);

  /// Whether [machine]'s card tunnel is up, with the ssh configuration this desktop publishes for its card.
  bool ready(Machine machine);

  /// Takes down the card tunnel and the published files of [machine], raised for a join that was not confirmed.
  Future<void> release(Machine machine);
}

/// Joins one verified admission at one click, confirmed before anything is saved.
class ProjectJoin extends ChangeNotifier {
  /// Takes the admission the row shows and the boundaries that check and carry it out.
  ProjectJoin({
    required this.offer,
    required this.discovery,
    required this.host,
    required this.machines,
    required this.settings,
  });

  /// The admission the row shows.
  final JoinOffered offer;

  /// Core's verified discovery, asked again before acting.
  final JoinDiscovery discovery;

  /// The tunnel and the account daemon.
  final JoinHost host;

  /// The watched accounts.
  final Machines machines;

  /// The confirmed project and host association.
  final Settings settings;

  /// Whether a join is running.
  bool busy = false;

  /// Whether the host confirmed the verified revision and it was saved.
  bool joined = false;

  /// What worked so far while not joined, so a partial result stays said.
  String? progress;

  /// The public refusal, without dependency errors or credential values.
  String? problem;

  bool _disposed = false;

  /// Follows the project on its host and saves the association, once.
  ///
  /// A join not confirmed takes down the card tunnel it raised, and the files it published, unless another join on
  /// the host still uses them or the account is watched already.
  Future<void> join() async {
    if (busy || joined) return;
    busy = true;
    problem = null;
    _notify();
    final name = offer.host.name;
    final joining = _joining[machines] ??= {};
    Machine? machine;
    var counted = false;
    var added = false;
    try {
      offer.check();
      final latest = (await discovery.admissions()).whereType<JoinOffered>().where((each) => each.key == offer.key);
      if (latest.length != 1 || !latest.single.same(offer)) {
        throw const RegistryRefusal('Core no longer verifies this admission as shown. Look at the list again.');
      }
      if (machines.all.any((each) => each.name == name && !offer.reaches(each))) {
        throw RegistryRefusal(
          'A machine named $name is watched here already and is not the account this host card reaches. '
          'Remove it under Machines, then join again.',
        );
      }
      joining[name] = (joining[name] ?? 0) + 1;
      counted = true;
      machine = _watched() ?? await _connect();
      if (!offer.reaches(machine) || !host.ready(machine)) {
        throw const RegistryRefusal('The tunnel did not confirm this host and your identity.');
      }
      progress = 'Connected to $name; not joined yet.';
      _notify();
      final before = await host.followed(machine, offer.project);
      final followed = before != null && offer.confirms(before) ? before : await host.follow(machine, offer);
      if (!offer.confirms(followed)) {
        throw const RegistryRefusal('The host did not confirm the verified project revision. Nothing was saved.');
      }
      await _adding(machine);
      added = true;
      await settings.rememberProjectHost(offer.project, name);
      joined = true;
      progress = null;
    } on RegistryRefusal catch (error) {
      problem = error.toString();
    } on Exception {
      problem = added
          ? 'The host confirmed the project and its account on $name is watched, but which host ${offer.project} is '
                'on could not be saved here. Try again.'
          : 'Joining could not be confirmed. Nothing was saved; try again.';
    } finally {
      if (counted) {
        final left = (joining[name] ?? 1) - 1;
        if (left > 0) {
          joining[name] = left;
        } else {
          joining.remove(name);
          if (machine != null && !joined && !machines.all.contains(machine)) await _letGo(machine);
        }
      }
      busy = false;
      _notify();
    }
  }

  /// Takes down what an unconfirmed join raised on its host, so a later join, with a rotated card too, starts anew.
  Future<void> _letGo(Machine machine) async {
    if (identical(_pending[machines]?[offer.host.name], machine)) _pending[machines]?.remove(offer.host.name);
    progress = null;
    try {
      await host.release(machine);
    } on Exception {
      problem = '${problem ?? ''} The tunnel raised for it could not be taken down completely.'.trim();
    }
  }

  /// The account already watched, or being connected, on this host, shared by every project there.
  Machine? _watched() {
    for (final machine in [...machines.all, ..._pending[machines]?.values.whereType<Machine>() ?? <Machine>[]]) {
      if (offer.reaches(machine)) return machine;
    }
    return null;
  }

  /// Opens one tunnel per host even when two rows join at once.
  Future<Machine> _connect() async {
    final connecting = _connecting[machines] ??= {};
    final key = offer.host.name;
    final running = connecting[key] ??= host.connect(offer);
    try {
      final machine = await running;
      (_pending[machines] ??= {})[key] = machine;
      return machine;
    } finally {
      if (identical(connecting[key], running)) connecting.remove(key);
    }
  }

  /// Adds the account once, even when two rows confirm at once.
  Future<void> _adding(Machine machine) async {
    final adding = _additions[machines] ??= {};
    final key = offer.host.name;
    final running = adding[key] ??= () async {
      if (!machines.all.contains(machine)) await machines.add(machine);
    }();
    try {
      await running;
      _pending[machines]?.remove(key);
    } finally {
      if (identical(adding[key], running)) adding.remove(key);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
