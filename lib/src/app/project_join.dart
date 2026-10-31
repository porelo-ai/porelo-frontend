import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart';
import 'run_here.dart' show WorkspaceRefused;
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
    required this.source,
    required this.revision,
    required List<String> signers,
  }) : signers = List.unmodifiable(signers);

  /// The project's name.
  final String project;

  /// The accepted host card.
  final PreparedHost host;

  /// The project repository's address, credential-free.
  final String source;

  /// The project revision Core verified as in force.
  final String revision;

  /// The project's signers Core verified, followed with as given.
  final List<String> signers;

  /// The row's identity: one project on one host.
  String get key => '$project@${host.name}';

  /// Refuses an incomplete verdict before anything is followed, written or connected.
  void check() {
    if (!RegExp(r'^[a-z][a-z0-9-]{0,62}$').hasMatch(project) ||
        !_repository(source) ||
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
        !machine.legacyHost &&
        machine.identity.isEmpty &&
        card != null &&
        card.name == host.name &&
        card.address == host.address &&
        card.sshPort == host.sshPort &&
        card.hostKey == host.sshHostKey;
  }

  /// Whether [followed] is the host's verified, in-force follow of this admission.
  bool confirms(Followed followed) =>
      followed.name == project && followed.url == source && followed.commit == revision && !followed.unverified;

  /// Whether [other] is the same verified admission, unchanged.
  bool same(JoinOffered other) =>
      other.key == key &&
      other.source == source &&
      other.revision == revision &&
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

  /// The access repository's address.
  final String repository;

  /// The verified admins who may grant reading it.
  final List<RegistryContact> whoMay;

  /// What the row says.
  String get words => RegistryRefusal(
    'The access file in $repository for $host cannot be read, so its projects are not known here.',
    whoMay: whoMay,
  ).toString();
}

final _connecting = Expando<Map<String, Future<Machine>>>();
final _pending = Expando<Map<String, Machine>>();
final _additions = Expando<Map<String, Future<void>>>();

bool _repository(String repository) {
  try {
    AccessCheckout.checkRepository(repository);
    return true;
  } on WorkspaceRefused {
    return false;
  }
}

/// Reads the answer of `porelo registry joinable --json`, or refuses it whole so it never shows as an empty list.
List<JoinAdmission> readJoinable(Object? json) {
  try {
    if (json is! Map<String, Object?>) throw const FormatException('not an object');
    final projects = json['projects'];
    final refused = json['refused'];
    if (projects is! List || refused is! List) throw const FormatException('no projects or refused');
    return [
      for (final entry in projects.cast<Map<String, Object?>>()) _offered(entry),
      for (final entry in refused.cast<Map<String, Object?>>())
        JoinUnreadable(
          host: _text(entry, 'host'),
          repository: _checked(_text(entry, 'access_repository')),
          whoMay: _contacts(entry['admins']),
        ),
    ];
  } on Object catch (error) {
    if (error is RegistryRefusal) rethrow;
    throw const RegistryRefusal('Core\'s answer on the projects you may join could not be read.');
  }
}

JoinOffered _offered(Map<String, Object?> entry) {
  final card = entry['host_card'];
  if (card is! Map<String, Object?>) throw const FormatException('no host card');
  final name = _text(entry, 'host');
  final host = PreparedHost.read({'name': name, ...card});
  if (host.name != name) throw const FormatException('the host card names another host');
  final signers = entry['signers'];
  if (signers is! List) throw const FormatException('no signers');
  return JoinOffered(
    project: _text(entry, 'project'),
    host: host,
    source: _text(entry, 'source'),
    revision: _text(entry, 'revision'),
    signers: signers.cast<String>(),
  );
}

String _checked(String repository) =>
    _repository(repository) ? repository : throw const FormatException('an access repository with credentials');

String _text(Map<String, Object?> entry, String key) {
  final value = entry[key];
  if (value is! String) throw FormatException('no $key');
  return value;
}

List<RegistryContact> _contacts(Object? json) => [
  for (final admin in (json as List? ?? const []).cast<Map<String, Object?>>())
    RegistryContact(
      login: _text(admin, 'login'),
      name: admin['name'] as String? ?? _text(admin, 'login'),
      email: admin['email'] as String?,
    ),
];

/// Core's verified discovery of where the person is admitted. Assumed until Core serves it.
abstract interface class JoinDiscovery {
  /// Every admission Core verified for the current person, and every access repository it could not read.
  Future<List<JoinAdmission>> admissions();
}

/// The host side of joining: the card tunnel and the account daemon's follow.
abstract interface class JoinHost {
  /// Opens, or reuses, the one tunnel to [host] through the person's agent, and names the watched account.
  Future<Machine> connect(PreparedHost host);

  /// What the account daemon follows as [project], or null when it follows nothing by that name.
  Future<Followed?> followed(Machine machine, String project);

  /// Follows [offer] on the account daemon with Core's signers, never unverified.
  Future<Followed> follow(Machine machine, JoinOffered offer);
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

  Machine? _machine;
  bool _disposed = false;

  /// Follows the project on its host and saves the association, once.
  Future<void> join() async {
    if (busy || joined) return;
    busy = true;
    problem = null;
    _notify();
    try {
      offer.check();
      final latest = (await discovery.admissions()).whereType<JoinOffered>().where((each) => each.key == offer.key);
      if (latest.length != 1 || !latest.single.same(offer)) {
        throw const RegistryRefusal('Core no longer verifies this admission as shown. Look at the list again.');
      }
      final machine = _machine ?? _watched() ?? await _connect();
      if (!offer.reaches(machine)) {
        throw const RegistryRefusal('The tunnel did not confirm this host and your identity.');
      }
      _machine = machine;
      progress = 'Connected to ${offer.host.name}; not joined yet.';
      _notify();
      final before = await host.followed(machine, offer.project);
      final followed = before != null && offer.confirms(before) ? before : await host.follow(machine, offer);
      if (!offer.confirms(followed)) {
        throw const RegistryRefusal('The host did not confirm the verified project revision. Nothing was saved.');
      }
      await _adding(machine);
      await settings.rememberProjectHost(offer.project, offer.host.name);
      joined = true;
      progress = null;
    } on RegistryRefusal catch (error) {
      problem = error.toString();
    } on Exception {
      problem = 'Joining could not be confirmed. Nothing was saved; try again.';
    } finally {
      busy = false;
      _notify();
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
    final running = connecting[key] ??= host.connect(offer.host);
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
    await (adding[key] ??= () async {
      if (!machines.all.contains(machine)) await machines.add(machine);
    }());
    adding.remove(key);
    _pending[machines]?.remove(key);
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
