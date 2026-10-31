import 'dart:convert';
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
  HostAccess({required this.registry, required this.settings, required this.identity, required this.transport});

  /// The shared registry whose accepted state controls every selection.
  final Registry registry;

  /// The durable public progress store.
  final Settings settings;

  /// The current proven identity, read again before every side effect.
  final HostAdminIdentity? Function() identity;

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

  /// No Core verb takes a person's request to a host admin; only a host admin files access.
  static const noRequests = 'No Core issue covers host access requests yet.';

  /// Why admission is unavailable; a person who is no host admin of [host] learns whom to ask instead.
  String? admitUnavailable(String host) => _admitRefusal(host)?.toString();

  RegistryRefusal? _admitRefusal(String host) {
    final reason = unavailable(host);
    if (reason == null || registry.accepted == null || registry.problem != null || registry.busy) {
      return reason == null ? null : RegistryRefusal(reason);
    }
    final assigned = registry.hosts.where((item) => item.host == host).firstOrNull;
    return RegistryRefusal(
      '$noRequests Only a host admin of $host may admit a project.',
      whoMay: [
        for (final contact in whoMay)
          if (assigned == null || assigned.admins.contains(contact.login)) contact,
      ],
    );
  }

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

  /// Shows the verified card key's bootstrap instruction for a separate terminal.
  String bootstrapCommand() {
    _authorize();
    return hostRootBootstrapCommand(_person(identity()!.login)!.key);
  }

  void _authorize([String? host]) {
    // The reason names who may already; the refusal carries no second list to be said again.
    if (unavailable(host) case final reason?) throw RegistryRefusal(reason);
  }

  void _authorizeExisting(String host) {
    checkHostName(host);
    _authorize(host);
    if (!registry.hosts.any((item) => item.host == host && item.admins.isNotEmpty)) {
      throw const RegistryRefusal('Choose a host with an assigned admin in the registry.');
    }
    if (settings.hostReturned(host)) throw const RegistryRefusal('The server was given back.');
  }

  void _authorizeChange(HostRegistryChange change) {
    if (const ['host-card', 'delete-card'].contains(change.action)) {
      _authorize(change.host);
    } else {
      _authorizeExisting(change.host);
    }
  }

  /// Rechecks setup authorization and resolves a completed return before renting again.
  Future<void> beginPreparation(String host) => _exclusive(host, () async {
    _authorize(host);
    if (!settings.hostReturned(host)) return;
    if (settings.hostRegistry(host)?.change.action != 'delete-card' || settings.hostRegistry(host)?.complete != true) {
      throw const RegistryRefusal('Publish the returned host card deletion before preparing this name again.');
    }
    await settings.reuseReturnedHost(host);
    _statuses.remove(host);
  });

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
    if (settings.hostReturned(host)) return progress?.change.action != 'delete-card' || progress?.complete != true;
    if (progress != null && !progress.complete) return true;
    final applied = _statuses[host]?.revision ?? settings.hostRegistryState(host).lastAppliedRevision;
    if (progress?.complete == true &&
        applied == progress?.confirmedRevision &&
        registry.accepted?.revision == progress?.revision) {
      return false;
    }
    return registry.accepted?.revision != null && applied != registry.accepted!.revision;
  }

  /// Files the checked SSH completion once; a retry never runs setup again.
  Future<void> publishReady(String host, PreparedHost card) => _exclusive(host, () => _publishReady(host, card));

  Future<void> _publishReady(String host, PreparedHost card) async {
    _authorize(host);
    if (settings.hostReturned(host)) throw const RegistryRefusal('The server was given back.');
    if (settings.hostRegistryState(host).cardNeedsVerification) {
      throw const RegistryRefusal(
        'The saved registry record lacks verified host card values. Verify the published card before replacing it.',
      );
    }
    final existing = settings.hostRegistry(host);
    if (existing?.change.action == 'host-card') {
      final same = jsonEncode(existing!.change.card?.stored) == jsonEncode(card.stored);
      if (!existing.complete) {
        if (!same) throw const FormatException('The completed host card changed during publication.');
        await _resume(host);
        return;
      }
      if (same) return;
    }
    if (jsonEncode(settings.hostRegistryState(host).publishedCard?.stored) == jsonEncode(card.stored)) return;
    await _begin(host, 'host-card', card: card);
  }

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
    checkHostName(host);
    if (_admitRefusal(host) case final refused?) throw refused;
    _authorizeExisting(host);
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

  /// No Core verb locks, lets back in or deletes a host account: `access.yml` names projects only.
  static const noHostWideChange =
      'No Core issue covers a host-wide lock, let back in or account deletion yet. Lock the person in each '
      "project's access instead.";

  /// Refuses a host-wide membership change after the usual host admin check, filing nothing.
  Future<void> membership({
    required String host,
    required String person,
    required String action,
    bool confirmed = false,
  }) => _exclusive(host, () async {
    _authorizeExisting(host);
    if (!const ['lock', 'unlock', 'purge'].contains(action)) {
      throw const FormatException('Unknown host membership action.');
    }
    throw const RegistryRefusal(noHostWideChange);
  });

  /// Brings only unconfirmed work to the host, or the newest accepted revision.
  Future<void> bringToHost(String host) => _exclusive(host, () async {
    _authorize(host);
    if (settings.hostReturned(host)) {
      await _deleteReturned(host);
    } else if (settings.hostUp(host)?.preparedHost case final card?
        when (settings.hostRegistry(host) == null || settings.hostRegistry(host)!.complete) &&
            !settings.hostRegistryState(host).cardNeedsVerification &&
            jsonEncode(settings.hostRegistryState(host).publishedCard?.stored) != jsonEncode(card.stored)) {
      await _publishReady(host, card);
    } else if (settings.hostRegistry(host) case final progress? when !progress.complete) {
      if (!const ['host-card', 'delete-card'].contains(progress.change.action)) _authorizeExisting(host);
      await _resume(host);
    } else {
      _authorizeExisting(host);
      await registry.refresh();
      _authorizeExisting(host);
      final revision = checkedRegistryRevision(registry.accepted!.revision!);
      final change = _change(host, 'deliver');
      await _keep(HostRegistryProgress(change: change, revision: revision, published: true));
      await _resume(host);
    }
  });

  /// Reads the host's applied registry after reconnecting, without changing it.
  Future<void> refreshStatus(String host) async {
    _authorizeExisting(host);
    final status = await transport.status(host);
    _checkStatus(host, status);
    _authorizeExisting(host);
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
      base: registry.accepted?.revision,
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
      if (!_staleSelection(pending)) {
        throw const RegistryRefusal('Bring the pending registry change to the host before another change.');
      }
      await settings.forgetUnfiledHostRegistry(host);
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
    _authorizeChange(progress.change);
    _checkNotReturned(progress.change);
    if (progress.revision == null) {
      if (_staleSelection(progress)) {
        await settings.forgetUnfiledHostRegistry(host);
        throw const RegistryRefusal('The selected card changed. Refresh the admission.');
      }
      final revision = await _file(progress.change);
      progress = HostRegistryProgress(change: progress.change, revision: revision, published: true);
      await _keep(progress);
      _authorizeChange(progress.change);
    } else if (!progress.published) {
      // An older record kept a signed commit whose push was never confirmed; only an accepted read proves it.
      await registry.refresh();
      _authorizeChange(progress.change);
      if (registry.accepted?.revision != progress.revision) {
        throw const RegistryRefusal(
          'An earlier registry change was signed but never confirmed published. Publish it from the registry '
          'checkout with Git, then bring it to the host again.',
        );
      }
      progress = HostRegistryProgress(change: progress.change, revision: progress.revision, published: true);
      await _keep(progress);
    }
    final revision = progress.revision!;
    if (const ['host-card', 'delete-card'].contains(progress.change.action)) {
      await _keep(
        HostRegistryProgress(change: progress.change, revision: revision, published: true, confirmedRevision: revision),
      );
      return;
    }
    _authorizeExisting(host);
    await registry.refresh();
    _authorizeExisting(host);
    // The host's own intake refuses anything that does not descend from what it applied.
    final target = checkedRegistryRevision(registry.accepted!.revision!);
    if (progress.change.action == 'admit' && !_holds(progress.change)) {
      throw const RegistryRefusal('The accepted registry no longer holds this admission. Admit the person again.');
    }
    var answer = await transport.status(host);
    _checkStatus(host, answer);
    _authorizeExisting(host);
    if (answer.revision != target) {
      _checkNotReturned(progress.change);
      // Intake can disappear across host restarts, so a saved upload receipt is insufficient.
      await transport.upload(host, target);
      await _keep(
        HostRegistryProgress(
          change: progress.change,
          revision: revision,
          published: true,
          uploaded: true,
          deliveryRevision: target == revision ? null : target,
        ),
      );
      _authorizeExisting(host);
      _checkNotReturned(progress.change);
      answer = await transport.sync(host, target);
    }
    _checkStatus(host, answer);
    if (answer.revision != target) {
      throw const FormatException('The host did not confirm the intended registry revision.');
    }
    final person = progress.change.person;
    final expected = switch (progress.change.action) {
      'admit' || 'unlock' => 'active',
      'lock' => 'locked',
      'purge' => 'purged',
      _ => null,
    };
    if (target == revision && expected != null && answer.people[person] != expected) {
      throw const FormatException('The host did not confirm the selected membership change.');
    }
    await _keep(
      HostRegistryProgress(
        change: progress.change,
        revision: revision,
        published: true,
        uploaded: true,
        confirmedRevision: target,
        deliveryRevision: target == revision ? null : target,
        lastAppliedRevision: target,
        words: answer.words,
      ),
    );
    _statuses[host] = answer;
  }

  /// Files [change] once through the registry, at its ID and base; a retry never makes a second commit.
  Future<String> _file(HostRegistryChange change) async {
    final accepted = registry.accepted?.revision;
    // A push whose receipt was lost: the accepted registry holds the admission already, so nothing is filed.
    if (change.action == 'admit' && _holds(change) && accepted != null) return checkedRegistryRevision(accepted);
    final filing = switch (change.action) {
      'admit' => RegistryFiling(
        RegistryFilingKind.hostAccess,
        host: change.host,
        person: change.person,
        id: change.id,
        base: change.base ?? accepted,
        content: hostAccessFile(
          registry.hosts.firstWhere((each) => each.host == change.host),
          person: change.person!,
          fingerprint: change.fingerprint!,
          project: change.project!,
          accessRepository: change.accessRepository!,
        ),
      ),
      'host-card' => RegistryFiling(
        RegistryFilingKind.hostCard,
        host: change.host,
        id: change.id,
        base: change.base ?? accepted,
        content: hostCardBody(change.card!),
      ),
      'delete-card' => throw const RegistryRefusal('No Core verb removes a host card from the registry yet.'),
      _ => throw const RegistryRefusal(noHostWideChange),
    };
    if (change.base != null && change.base != accepted) return _readAgainAndAsk(change.host);
    try {
      return checkedRegistryRevision((await registry.file(filing)).revision);
    } on RegistryRefusal {
      await registry.refresh();
      if (registry.accepted?.revision != filing.base) return _readAgainAndAsk(change.host);
      rethrow;
    }
  }

  /// The registry moved past the change's base: the change is dropped, never filed on another base.
  Future<Never> _readAgainAndAsk(String host) async {
    await settings.forgetUnfiledHostRegistry(host);
    throw const RegistryRefusal('The registry changed since this was chosen. It was read again; choose again.');
  }

  /// Whether the accepted registry admits [change]'s project for its person under its fingerprint.
  bool _holds(HostRegistryChange change) {
    final host = registry.hosts.where((each) => each.host == change.host).firstOrNull;
    return host != null &&
        host.adminFingerprints[change.person] == change.fingerprint &&
        host.projects.any(
          (each) =>
              each.name == change.project &&
              each.admin == change.person &&
              each.accessRepository == change.accessRepository,
        );
  }

  bool _staleSelection(HostRegistryProgress progress) =>
      progress.revision == null &&
      progress.change.action == 'admit' &&
      _person(progress.change.person!)?.fingerprint != progress.change.fingerprint;

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
    return settings.rememberHostRegistry(progress);
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
    if (access == null) return _registryDeletionProblem();
    await access.confirmGivenBack(host, session);
    return null;
  } on RegistryRefusal catch (refused) {
    return _registryDeletionProblem(refused);
  } on Exception {
    return _registryDeletionProblem();
  }
}

/// Reconstructs pending deletion recovery from provider success after a restart.
String? pendingHostRegistryGiveBack({required String host, required Settings settings, HostAccess? access}) {
  if (!settings.hostReturned(host)) return null;
  final progress = settings.hostRegistry(host);
  if (progress?.change.action == 'delete-card' && progress?.complete == true) return null;
  final reason = access?.unavailable(host);
  return _registryDeletionProblem(reason == null ? null : RegistryRefusal(reason, whoMay: access!.whoMay));
}

String _registryDeletionProblem([RegistryRefusal? refused]) {
  final contacts = (refused?.whoMay ?? <RegistryContact>[])
      .map((person) => '${person.name} (${person.login})${person.email == null ? '' : ', ${person.email}'}')
      .join('; ');
  return 'The server was given back; its registry card still needs deletion. '
      '${refused?.words ?? 'Retry publication without giving it back again.'}'
      '${contacts.isEmpty ? '' : ' Ask $contacts.'}';
}
