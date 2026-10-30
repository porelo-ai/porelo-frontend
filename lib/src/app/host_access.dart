import 'dart:math';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_access_contract.dart';
import 'host_runs.dart' show hostGivenBack;
import 'host_session.dart';
import 'registry.dart';
import 'settings.dart';

/// The current identity proven by Core, never a typed account name.
class HostAdminIdentity {
  /// Keeps Core’s proven login and current key fingerprint.
  const HostAdminIdentity(this.login, this.fingerprint);

  /// The central-forge login.
  final String login;

  /// The current proven public key fingerprint.
  final String fingerprint;
}

/// Publishes signed host state and retains every unconfirmed step across restarts.
class HostAccess {
  /// Uses the shared verified registry and isolated write and delivery boundaries.
  HostAccess({
    required this.registry,
    required this.settings,
    required this.identity,
    required this.writer,
    required this.transport,
  });

  /// The shared registry whose accepted state controls every selection.
  final Registry registry;

  /// The durable public progress store.
  final Settings settings;

  /// The current proven identity, read again before every side effect.
  final HostAdminIdentity? Function() identity;

  /// Core’s signing boundary and the registry’s publication boundary.
  final HostRegistryWriter writer;

  /// The pinned host’s checked registry intake and sync boundary.
  final HostRegistryTransport transport;
  final _busy = <String>{};
  final _statuses = <String, HostRegistryStatus>{};

  /// The host admins accepted from owners.yml, with their available email.
  List<RegistryContact> get whoMay => [
    for (final admin in registry.accepted?.hostAdmins ?? <RegistryOwner>[])
      if (!admin.backup)
        RegistryContact(
          login: admin.login,
          name: _person(admin.login)?.name ?? admin.login,
          email: _person(admin.login)?.contactEmail,
        ),
  ];

  RegistryCard? _person(String login) => registry.selectable.where((card) => card.login == login).firstOrNull;

  /// Why preparation or admission is unavailable, including who may do it.
  String? unavailable([String? host]) {
    if (registry.accepted == null || registry.problem != null || registry.busy) {
      return 'Refresh the registry before changing a host.';
    }
    final actor = identity();
    final card = actor == null ? null : _person(actor.login);
    final admins = registry.accepted!.hostAdmins;
    final permitted =
        actor != null &&
        card?.fingerprint == actor.fingerprint &&
        admins.any((admin) => !admin.backup && admin.login == actor.login && admin.fingerprint == actor.fingerprint);
    final assigned = host == null ? null : registry.hosts.where((item) => item.host == host).firstOrNull;
    if (!permitted || assigned != null && !assigned.admins.contains(actor.login)) {
      final contacts = whoMay.where((contact) => assigned == null || assigned.admins.contains(contact.login));
      final names = contacts
          .map((contact) => '${contact.name} (${contact.login})${contact.email == null ? '' : ', ${contact.email}'}')
          .join('; ');
      return 'Only a host admin named in owners.yml may do this.${names.isEmpty ? '' : ' Ask $names.'}';
    }
    return null;
  }

  /// Rechecks a retained Prepare callback immediately before it can rent a server.
  Future<void> prepare(Future<void> Function() start) async {
    _authorize();
    await start();
  }

  /// Refuses a stale callback before it can change or rent a host.
  void requireAdmin([String? host]) => _authorize(host);

  void _authorize([String? host]) {
    if (unavailable(host) case final reason?) throw RegistryRefusal(reason, whoMay: whoMay);
  }

  /// The exact intended revision waiting for this host, if any.
  String? pendingRevision(String host) {
    final progress = settings.hostRegistry(host);
    return progress?.complete == true ? null : progress?.revision;
  }

  /// The last host-confirmed answer, independent of the registry's newest commit.
  HostRegistryStatus? statusFor(String host) => _statuses[host];

  /// Whether Git is ahead of what this host has confirmed.
  bool notOnHostYet(String host) {
    final progress = settings.hostRegistry(host);
    if (progress != null && !progress.complete) return true;
    final applied = _statuses[host]?.revision ?? progress?.lastAppliedRevision;
    return registry.accepted?.revision != null && applied != registry.accepted!.revision;
  }

  /// Files the checked SSH completion once; a retry never runs setup again.
  Future<void> publishReady(String host, PreparedHost card) => _exclusive(host, () async {
    _authorize(host);
    final existing = settings.hostRegistry(host);
    if (existing?.change.action == 'host-card') {
      if (existing!.change.card?.fingerprint != card.fingerprint ||
          existing.change.card?.stored.toString() != card.stored.toString()) {
        throw const FormatException('The completed host card changed during publication.');
      }
      await _resume(host);
      return;
    }
    await _begin(host, 'host-card', card: card);
  });

  /// Deletes a card only after the provider's checked give-back confirmation.
  Future<void> confirmGivenBack(String host, HostSession session) async {
    if (!hostGivenBack(session)) return;
    await settings.rememberHostReturned(host);
    await _exclusive(host, () => _deleteReturned(host));
  }

  /// Whether a confirmed give-back is already awaiting publication or complete.
  bool givenBack(String host) => settings.hostReturned(host);

  /// Admits only a selected trusted card with its project and access address.
  Future<void> admit({
    required String host,
    required String person,
    required String project,
    required String accessRepository,
  }) => _exclusive(host, () async {
    _authorize(host);
    if (!registry.hosts.any((item) => item.host == host)) throw const RegistryRefusal('Choose a host in the registry.');
    final card = _person(person);
    if (card == null) throw const RegistryRefusal('Choose a person whose card Core trusts.');
    await _begin(
      host,
      'admit',
      person: card.login,
      fingerprint: card.fingerprint,
      project: project,
      accessRepository: accessRepository,
    );
  });

  /// Changes only a host membership; purge is a separate confirmed decision after lock.
  Future<void> membership({
    required String host,
    required String person,
    required String action,
    bool confirmed = false,
  }) => _exclusive(host, () async {
    _authorize(host);
    if (!const ['lock', 'unlock', 'purge'].contains(action)) {
      throw const FormatException('Unknown host membership action.');
    }
    final status = await transport.status(host);
    _checkStatus(host, status);
    if (!status.people.containsKey(person)) throw const RegistryRefusal('Choose a person on this host.');
    if (action == 'purge' && (!confirmed || status.people[person] != 'locked')) {
      throw const RegistryRefusal('Lock first. Deleting the account is a separate permanent decision.');
    }
    await _begin(host, action, person: person);
  });

  /// Brings only unconfirmed work to the host, or the newest accepted revision.
  Future<void> bringToHost(String host) => _exclusive(host, () async {
    _authorize(host);
    if (settings.hostReturned(host)) {
      await _deleteReturned(host);
    } else if (settings.hostRegistry(host) case final progress? when !progress.complete) {
      await _resume(host);
    } else {
      final revision = checkedRegistryRevision(registry.accepted!.revision!);
      final change = _change(host, 'deliver');
      await _keep(HostRegistryProgress(change: change, revision: revision, published: true));
      await _resume(host);
    }
  });

  /// Reads the host's applied registry after reconnecting, without changing it.
  Future<void> refreshStatus(String host) async {
    final status = await transport.status(host);
    _checkStatus(host, status);
    _statuses[host] = status;
  }

  HostRegistryChange _change(
    String host,
    String action, {
    String? person,
    String? fingerprint,
    String? project,
    String? accessRepository,
    PreparedHost? card,
  }) => HostRegistryChange.read(
    HostRegistryChange(
      id: List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
      host: host,
      action: action,
      person: person,
      fingerprint: fingerprint,
      project: project,
      accessRepository: accessRepository,
      card: card,
    ).stored,
  );

  Future<void> _begin(
    String host,
    String action, {
    String? person,
    String? fingerprint,
    String? project,
    String? accessRepository,
    PreparedHost? card,
  }) async {
    if (settings.hostRegistry(host) case final pending? when !pending.complete) {
      throw const RegistryRefusal('Bring the pending registry change to the host before another change.');
    }
    await _keep(
      HostRegistryProgress(
        change: _change(
          host,
          action,
          person: person,
          fingerprint: fingerprint,
          project: project,
          accessRepository: accessRepository,
          card: card,
        ),
      ),
    );
    await _resume(host);
  }

  Future<void> _resume(String host) async {
    var progress = settings.hostRegistry(host)!;
    if (progress.complete) return;
    _authorize(host);
    _checkNotReturned(progress.change);
    if (progress.revision == null) {
      if (progress.change.action == 'admit' &&
          _person(progress.change.person!)?.fingerprint != progress.change.fingerprint) {
        throw const RegistryRefusal('The selected card changed. Refresh the admission.');
      }
      final revision = checkedRegistryRevision(await writer.file(progress.change));
      progress = HostRegistryProgress(change: progress.change, revision: revision);
      await _keep(progress);
    }
    final revision = progress.revision!;
    if (!progress.published) {
      _authorize(host);
      await writer.publish(revision);
      progress = HostRegistryProgress(change: progress.change, revision: revision, published: true);
      await _keep(progress);
    }
    if (const ['host-card', 'delete-card'].contains(progress.change.action)) {
      await _keep(
        HostRegistryProgress(change: progress.change, revision: revision, published: true, confirmedRevision: revision),
      );
      return;
    }
    _authorize(host);
    if (!progress.uploaded) {
      await transport.upload(host, revision);
      progress = HostRegistryProgress(change: progress.change, revision: revision, published: true, uploaded: true);
      await _keep(progress);
    }
    _authorize(host);
    var answer = await transport.status(host);
    _checkStatus(host, answer);
    if (answer.revision != revision) {
      _authorize(host);
      _checkNotReturned(progress.change);
      answer = await transport.sync(host, revision);
    }
    _checkStatus(host, answer);
    if (answer.revision != revision) {
      throw const FormatException('The host did not confirm the intended registry revision.');
    }
    final person = progress.change.person;
    final expected = switch (progress.change.action) {
      'admit' || 'unlock' => 'active',
      'lock' => 'locked',
      'purge' => 'purged',
      _ => null,
    };
    if (expected != null && answer.people[person] != expected) {
      throw const FormatException('The host did not confirm the selected membership change.');
    }
    await _keep(
      HostRegistryProgress(
        change: progress.change,
        revision: revision,
        published: true,
        uploaded: true,
        confirmedRevision: revision,
        lastAppliedRevision: revision,
        words: answer.words,
      ),
    );
    _statuses[host] = answer;
  }

  void _checkStatus(String host, HostRegistryStatus answer) {
    if (answer.host != host) throw const FormatException('The registry answer names another host.');
    checkedRegistryRevision(answer.revision);
    for (final person in answer.people.keys) {
      checkAdminName(person);
    }
  }

  void _checkNotReturned(HostRegistryChange change) {
    if (settings.hostReturned(change.host) && change.action != 'delete-card') {
      throw const RegistryRefusal('The server was given back. Only its pending registry deletion may continue.');
    }
  }

  Future<void> _deleteReturned(String host) async {
    if (settings.hostRegistry(host)?.change.action != 'delete-card') {
      await _keep(HostRegistryProgress(change: _change(host, 'delete-card')));
    }
    _authorize(host);
    await _resume(host);
  }

  Future<void> _keep(HostRegistryProgress progress) {
    _checkNotReturned(progress.change);
    return settings.rememberHostRegistry(
      HostRegistryProgress.read({
        ...progress.stored,
        'last_applied_revision':
            ?(progress.lastAppliedRevision ?? settings.hostRegistry(progress.change.host)?.lastAppliedRevision),
      }),
    );
  }

  Future<void> _exclusive(String host, Future<void> Function() work) async {
    checkHostName(host);
    if (!_busy.add(host)) throw const RegistryRefusal('A change for this host is still running.');
    try {
      await work();
    } finally {
      _busy.remove(host);
    }
  }
}

/// Keeps provider success before attempting card deletion, for both teardown paths.
///
/// Returns an unfinished publication message while retaining the deletion request.
Future<String?> confirmHostRegistryGiveBack({
  required String host,
  required HostSession session,
  required Settings settings,
  HostAccess? access,
}) async {
  if (!hostGivenBack(session)) return null;
  final record = settings.hostUp(host);
  if (record?.hostName.isNotEmpty != true) return null;
  await settings.rememberHostReturned(host);
  try {
    if (access == null) return 'The server was given back; its registry card still needs deletion.';
    await access.confirmGivenBack(host, session);
    return null;
  } on Exception {
    return 'The server was given back; its registry card still needs deletion. Retry publication without giving it back again.';
  }
}
