import 'package:porelo_host/porelo_host.dart';

import 'registry_checkout.dart';
import 'run_here.dart' show WorkspaceRefused;

/// A signed registry change whose request ID makes filing safe to retry.
class HostRegistryChange {
  /// Keeps the public request whose ID Core uses to deduplicate signing.
  const HostRegistryChange({
    required this.id,
    required this.host,
    required this.action,
    this.person,
    this.fingerprint,
    this.project,
    this.accessRepository,
    this.card,
  });

  /// The durable random request ID.
  final String id;

  /// The host this state belongs to.
  final String host;

  /// The host operation: admit, lock, unlock, purge, host-card or delete-card.
  final String action;

  /// The selected registry login or host membership.
  final String? person;

  /// The selected trusted card’s key fingerprint.
  final String? fingerprint;

  /// The project admitted for the selected admin.
  final String? project;

  /// The project’s credential-free access repository address.
  final String? accessRepository;

  /// The checked public completion, present only for host-card publication.
  final PreparedHost? card;

  /// The single adapter shape for Core's signed host changes.
  Map<String, Object?> get stored => {
    'id': id,
    'host': host,
    'action': action,
    'person': ?person,
    'fingerprint': ?fingerprint,
    'project': ?project,
    'access_repository': ?accessRepository,
    'card': ?card?.stored,
  };

  /// Reads a persisted request without accepting shell words or arbitrary actions.
  factory HostRegistryChange.read(Object? value) {
    if (value is! Map) throw const FormatException('The pending host change must be an object.');
    String text(String key) {
      final item = value[key];
      if (item is! String || item.isEmpty || item.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
        throw FormatException('Invalid pending $key.');
      }
      return item;
    }

    final host = text('host');
    checkHostName(host);
    final action = text('action');
    if (!const ['admit', 'lock', 'unlock', 'purge', 'host-card', 'delete-card', 'deliver'].contains(action)) {
      throw const FormatException('Unknown host change.');
    }
    final id = text('id');
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw const FormatException('Invalid host change ID.');
    final person = value['person'] == null ? null : text('person');
    if (person != null) checkAdminName(person);
    final fingerprint = value['fingerprint'] == null ? null : text('fingerprint');
    if (fingerprint != null && !RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid person fingerprint.');
    }
    final project = value['project'] == null ? null : text('project');
    if (project != null) checkAdminName(project);
    final repository = value['access_repository'] == null ? null : text('access_repository');
    if (repository != null) {
      try {
        RegistryCheckout.checkRepository(repository);
      } on WorkspaceRefused {
        throw const FormatException('Use a repository address without credentials or unsafe Git syntax.');
      }
    }
    if (action == 'admit' && (person == null || fingerprint == null || project == null || repository == null)) {
      throw const FormatException('Admission needs a person, fingerprint, project and access repository.');
    }
    if (const ['lock', 'unlock', 'purge'].contains(action) && person == null) {
      throw const FormatException('Choose a host membership.');
    }
    final card = value['card'] == null ? null : PreparedHost.read(value['card']);
    if (action == 'host-card' && (card == null || card.values['name'] != host)) {
      throw const FormatException('Choose the completed SSH host card.');
    }
    return HostRegistryChange(
      id: id,
      host: host,
      action: action,
      person: person,
      fingerprint: fingerprint,
      project: project,
      accessRepository: repository,
      card: card,
    );
  }
}

/// Core signs and commits once per request ID; publication retries the same commit.
abstract interface class HostRegistryWriter {
  /// Signs and commits once per request ID, returning its exact revision.
  Future<String> file(HostRegistryChange change);

  /// Publishes the existing signed revision without creating another commit.
  Future<void> publish(String revision);

  /// Checks verified registry ancestry; an unknown or forked commit returns false.
  Future<bool> descendsFrom(String revision, String ancestor);
}

/// The public result of registry sync or status from the pinned host.
class HostRegistryStatus {
  /// Keeps a host answer with its exact applied registry revision.
  const HostRegistryStatus({required this.host, required this.revision, required this.people, required this.words});

  /// The host this state belongs to.
  final String host;

  /// The applied registry commit, never a project-access commit.
  final String revision;

  /// The confirmed host memberships: active, locked or purged.
  final Map<String, String> people;

  /// The host’s own public result.
  final String words;
}

/// Checks an exact Git object ID before publication, delivery or confirmation.
String checkedRegistryRevision(String value) {
  if (!RegExp(r'^(?:[a-f0-9]{40}|[a-f0-9]{64})$').hasMatch(value)) {
    throw const FormatException('Invalid registry revision.');
  }
  return value;
}

/// The durable boundary between signing, publication, upload and host sync.
class HostRegistryProgress {
  /// Keeps the latest durably completed step.
  const HostRegistryProgress({
    required this.change,
    this.revision,
    this.published = false,
    this.uploaded = false,
    this.confirmedRevision,
    this.lastAppliedRevision,
    this.words,
    this.deliveryRevision,
    this.publishedCard,
  });

  /// The original immutable public request.
  final HostRegistryChange change;

  /// The signed intended commit, absent before filing.
  final String? revision;

  /// Whether publication of the signed revision succeeded.
  final bool published;

  /// Whether the host confirmed intake of the exact bundle.
  final bool uploaded;

  /// The final confirmed commit for this operation.
  final String? confirmedRevision;

  /// The host’s last applied registry revision, independent of card publication.
  final String? lastAppliedRevision;

  /// The host’s result, absent before confirmation.
  final String? words;

  /// The verified descendant used for delivery when newer changes supersede this one.
  final String? deliveryRevision;

  /// The last public host card whose publication was confirmed, absent after deletion.
  final PreparedHost? publishedCard;

  /// Whether every required step was confirmed.
  bool get complete => revision != null && (deliveryRevision ?? revision) == confirmedRevision;

  /// The public retry record kept in Settings.
  Map<String, Object?> get stored => {
    'change': change.stored,
    'revision': ?revision,
    'published': published,
    'uploaded': uploaded,
    'confirmed_revision': ?confirmedRevision,
    'last_applied_revision': ?lastAppliedRevision,
    'words': ?words,
    'delivery_revision': ?deliveryRevision,
    'published_card': ?publishedCard?.stored,
  };

  /// Refuses malformed progress rather than forgetting unfinished work.
  factory HostRegistryProgress.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid host registry progress.');
    String? revision(String key) {
      final found = value[key];
      if (found == null) return null;
      if (found is! String) throw FormatException('Invalid $key.');
      return checkedRegistryRevision(found);
    }

    final published = value['published'];
    final uploaded = value['uploaded'];
    final intended = revision('revision');
    final confirmed = revision('confirmed_revision');
    final words = value['words'];
    final change = HostRegistryChange.read(value['change']);
    final publicationOnly = const ['host-card', 'delete-card'].contains(change.action);
    final delivery = revision('delivery_revision');
    final publishedCard = value['published_card'] == null ? null : PreparedHost.read(value['published_card']);
    if (published is! bool ||
        uploaded is! bool ||
        published && intended == null ||
        uploaded && !published ||
        delivery != null && (intended == null || !published || publicationOnly) ||
        confirmed != null && (confirmed != (delivery ?? intended) || !published || !publicationOnly && !uploaded) ||
        publishedCard != null && (publishedCard.values['name'] != change.host) ||
        words != null && words is! String) {
      throw const FormatException('Invalid host registry progress ordering.');
    }
    return HostRegistryProgress(
      change: change,
      revision: intended,
      published: published,
      uploaded: uploaded,
      confirmedRevision: confirmed,
      lastAppliedRevision: revision('last_applied_revision'),
      words: words as String?,
      deliveryRevision: delivery,
      publishedCard: publishedCard ?? (change.action == 'host-card' && published ? change.card : null),
    );
  }
}

/// Delivers an exact signed revision over the host's owned, pinned SSH tunnel.
///
/// Upload must verify intake before returning. Sync rejects any state that is not
/// a descendant of the applied revision. Status reports the registry revision,
/// never a project's access revision. No central-forge credential reaches it.
abstract interface class HostRegistryTransport {
  /// Uploads and checks the exact signed registry bundle through pinned SSH.
  Future<void> upload(String host, String revision);

  /// Applies a descendant and reports the host’s confirmed membership results.
  Future<HostRegistryStatus> sync(String host, String revision);

  /// Reads the applied registry state without changing it.
  Future<HostRegistryStatus> status(String host);
}
