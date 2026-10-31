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
        (homeserver != null && !_homeserver(homeserver!)) ||
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
  const JoinUnreadable({required this.host, required this.repository, this.project, this.whoMay = const []});

  /// The host whose access entries name the repository.
  final String host;

  /// The access repository's address, or null when the registry refused the host's own access file or the address
  /// may hold a credential and is not shown.
  final String? repository;

  /// A project the repository is named for, or null for the host's own access file.
  final String? project;

  /// The verified admins who may grant reading it, or the host's admins for its own access file.
  final List<RegistryContact> whoMay;

  /// What the row says.
  String get words => RegistryRefusal(
    repository != null
        ? 'The access file in $repository for $host cannot be read, so its projects are not known here.'
        : project == null
        ? 'The registry refused the access file of $host, so no project on it is known here.'
        : 'The access repository of project $project on $host cannot be read, so its projects are not known here. '
              'Its address is not shown, as it may hold a credential.',
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
final _holds = Expando<Map<Machine, int>>();
final _unsaved = Expando<Set<String>>();

/// A key's `SHA256:` fingerprint, as the daemon names the keys a follow pinned.
String _fingerprint(String key) =>
    'SHA256:${base64Encode(sha256.convert(base64Decode(key.split(' ')[1])).bytes).replaceAll('=', '')}';

/// Core's project name: `[a-z0-9][a-z0-9-]{0,62}`.
final _project = RegExp(r'^[a-z0-9][a-z0-9-]{0,62}$');

/// The ssh user git hands to ssh, never a secret: it cannot start an option.
const _sshUser = r'[A-Za-z0-9][A-Za-z0-9._-]*';

/// A host as a repository address names it, a name or an IPv4 address, or an IPv6 address in brackets for `ssh://`.
const _addressHost = r'[A-Za-z0-9][A-Za-z0-9.-]*';

/// The schemes git hands to ssh, whose host ends at the first slash alone.
const _sshSchemes = {'ssh://', 'git+ssh://', 'ssh+git://'};

/// Whether an address Core answered may carry a credential, in any form git, ssh or libcurl reads one: a user part
/// beside an `https` host, anything but a plain ssh user before an ssh host, a query or fragment that may hold a token,
/// an at sign spelled `%40`, or an `@` anywhere after the host.
bool _credential(String address) {
  if (address.contains('?') || address.contains('#') || address.toLowerCase().contains('%40')) return true;
  final scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').matchAsPrefix(address);
  if (scheme == null) {
    // `user@host:path`: ssh takes the user up to the at sign; a second one is no plain user, or follows the host.
    final at = address.indexOf('@');
    return at >= 0 && (!RegExp('^$_sshUser\$').hasMatch(address.substring(0, at)) || address.contains('@', at + 1));
  }
  final rest = address.substring(scheme.end);
  final slash = rest.indexOf('/');
  if (slash >= 0 && rest.contains('@', slash)) return true;
  final authority = slash < 0 ? rest : rest.substring(0, slash);
  final at = authority.indexOf('@');
  if (at < 0) return false;
  final ssh = _sshSchemes.contains(scheme.group(0)!.toLowerCase());
  return !ssh || authority.contains('@', at + 1) || !RegExp('^$_sshUser\$').hasMatch(authority.substring(0, at));
}

/// Whether [port], as an address writes it, is absent or one of 1 to 65535.
bool _port(String? port) => port == null || (int.parse(port) >= 1 && int.parse(port) <= 65535);

/// Whether [host] is a host name, or an IPv6 address in brackets that reads as one.
bool _host(String host) {
  if (!host.startsWith('[')) return RegExp('^$_addressHost\$').hasMatch(host);
  if (!host.endsWith(']')) return false;
  try {
    Uri.parseIPv6Address(host.substring(1, host.length - 1));
    return true;
  } on FormatException {
    return false;
  }
}

/// Whether a credential-free repository address is in a form this interface follows: `https://host[:port]/path`,
/// `ssh://[user@]host[:port]/path` or `user@host:path`, its port one of 1 to 65535.
bool _usable(String address) {
  if (_credential(address) || RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(address)) return false;
  const path = r'[A-Za-z0-9_.~+-][A-Za-z0-9_./~+-]*';
  final ssh = RegExp('^ssh://(?:$_sshUser@)?($_addressHost|\\[[0-9A-Fa-f:.]+\\])(?::([0-9]{1,5}))?/$path\$')
      .firstMatch(address);
  if (ssh != null) return _host(ssh.group(1)!) && _port(ssh.group(2));
  if (RegExp('^$_sshUser@$_addressHost:$path\$').hasMatch(address)) return true;
  final https = RegExp('^https://($_addressHost)(?::([0-9]{1,5}))?(/.*)\$').firstMatch(address);
  final uri = Uri.tryParse(address);
  return https != null &&
      _port(https.group(2)) &&
      uri != null &&
      uri.host.toLowerCase() == https.group(1)!.toLowerCase() &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.length > 1;
}

/// Whether a homeserver Core answered is an `https://` base URL with a real host, as Core's rule has it: no user part,
/// query or fragment, a port of 1 to 65535, and at most a path.
bool _homeserver(String url) {
  final https = RegExp('^https://($_addressHost|\\[[0-9A-Fa-f:.]+\\])(?::([0-9]{1,5}))?(/[^\\s]*)?\$').firstMatch(url);
  return https != null && !_credential(url) && _host(https.group(1)!) && _port(https.group(2));
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
      // One row per repository and host, as several refused projects may share one access repository; one whose
      // address is not shown is a row of its project.
      final at = '${row.repository ?? row.project} ${row.host}';
      final same = unreadable[at];
      unreadable[at] = same == null
          ? row
          : JoinUnreadable(
              host: row.host,
              repository: row.repository,
              project: row.project,
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
  final project = ofTheHost ? null : _text(entry, 'project');
  final repository = ofTheHost ? null : _text(entry, 'access_repository');
  return (
    ofTheHost ? null : '$project@$host',
    JoinUnreadable(
      host: host,
      // An address that may hold a credential is never kept or shown; the row names its project instead.
      repository: repository == null || _credential(repository) ? null : repository,
      project: project,
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
  if (homeserver != null && _credential(homeserver)) throw const FormatException('a homeserver with credentials');
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
  if (homeserver != null && !_homeserver(homeserver)) {
    return (key, unusable('its homeserver is not an https base URL this interface reaches'));
  }
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

  /// Whether [machine]'s card holds the person's usable key now; an account reached with an older key is raised anew.
  Future<bool> current(Machine machine);

  /// Raises [machine]'s card tunnel, watched or raised by another join, when it is not up.
  Future<void> raise(Machine machine);

  /// What the account daemon follows as [project], or null when it follows nothing by that name.
  Future<Followed?> followed(Machine machine, String project);

  /// Follows [offer] on the account daemon with Core's signers, never unverified, and answers how the follow ended;
  /// what is in force is read with [followed].
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
  /// A join not confirmed takes down the card tunnel it raised, and the files it published, once no other join holds
  /// them and unless the account is watched already.
  Future<void> join() async {
    if (busy || joined) return;
    busy = true;
    problem = null;
    _notify();
    final name = offer.host.name;
    Machine? held;
    var confirmed = false;
    try {
      offer.check();
      final latest = (await discovery.admissions()).whereType<JoinOffered>().where((each) => each.key == offer.key);
      if (latest.length != 1 || !latest.single.same(offer)) {
        throw const RegistryRefusal('Core no longer verifies this admission as shown. Look at the list again.');
      }
      for (final each in machines.all) {
        if (offer.reaches(each)) continue;
        if (each.name == name) {
          throw RegistryRefusal(
            'A machine named $name is watched here already and is not the account this host card reaches. '
            'Remove it under Machines, then join again.',
          );
        }
        if (each.hostCard?.name == name) {
          throw RegistryRefusal(
            'The machine ${each.name} is watched here already through a card of host $name, and is not the account '
            'this host card reaches. Remove it under Machines, then join again.',
          );
        }
      }
      var machine = _watched();
      if (machine != null) {
        held = _hold(machine);
        if (!await host.current(machine)) {
          // An account reached with a key the person no longer uses is raised anew with their card now.
          held = null;
          await _unhold(machine);
          machine = null;
        } else if (!host.ready(machine)) {
          await host.raise(machine);
        }
      }
      if (machine == null) {
        machine = await _connect();
        held = _hold(machine);
      }
      if (!offer.reaches(machine) || !host.ready(machine)) {
        throw const RegistryRefusal('The tunnel did not confirm this host and your identity.');
      }
      progress = 'Connected to $name; not joined yet.';
      _notify();
      final before = await host.followed(machine, offer.project);
      if (before == null || !offer.confirms(before)) {
        final answer = await host.follow(machine, offer);
        if (!answer.inForce) {
          final detail = answer.detail.trim();
          throw RegistryRefusal(
            'The host did not follow ${offer.project}: ${answer.words}${detail.isEmpty ? '' : ' ($detail)'}. '
            'Nothing was saved.',
          );
        }
        // Only `Following` says which access commit and signers are in force.
        final after = await host.followed(machine, offer.project);
        if (after == null || !offer.confirms(after)) {
          throw const RegistryRefusal('The host did not confirm the verified project revision. Nothing was saved.');
        }
      }
      confirmed = true;
      await _adding(machine);
      await settings.rememberProjectHost(offer.project, name);
      joined = true;
      progress = null;
    } on RegistryRefusal catch (error) {
      problem = error.toString();
    } on Exception {
      problem = !confirmed || held == null || !machines.all.contains(held)
          ? 'Joining could not be confirmed. Nothing was saved; try again.'
          : _unsaved[machines]?.contains(name) ?? false
          ? 'The host confirmed the project and its account on $name is watched, but the list of watched machines '
                'could not be saved here. Try again.'
          : 'The host confirmed the project and its account on $name is watched, but which host ${offer.project} is '
                'on could not be saved here. Try again.';
    } finally {
      if (held != null) await _unhold(held);
      busy = false;
      _notify();
    }
  }

  /// Counts this join among those holding [machine], so it is taken down only once the last of them let it go.
  Machine _hold(Machine machine) {
    final holds = _holds[machines] ??= Map.identity();
    holds[machine] = (holds[machine] ?? 0) + 1;
    return machine;
  }

  /// Lets go of [machine]; the last join holding it takes it down unless its account is watched.
  Future<void> _unhold(Machine machine) async {
    final holds = _holds[machines] ??= Map.identity();
    final left = (holds[machine] ?? 1) - 1;
    if (left > 0) {
      holds[machine] = left;
      return;
    }
    holds.remove(machine);
    if (!machines.all.contains(machine)) await _letGo(machine);
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

  /// Adds the account once, even when two rows confirm at once, and saves the list again after a save that failed.
  Future<void> _adding(Machine machine) async {
    final adding = _additions[machines] ??= {};
    final key = offer.host.name;
    final running = adding[key] ??= () async {
      try {
        if (!machines.all.contains(machine)) {
          await machines.add(machine);
        } else if (_unsaved[machines]?.contains(key) ?? false) {
          await machines.remember();
        }
        _unsaved[machines]?.remove(key);
      } on Object {
        // Added and watched, and not saved: a retry saves the list again.
        if (machines.all.contains(machine)) (_unsaved[machines] ??= {}).add(key);
        rethrow;
      }
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
