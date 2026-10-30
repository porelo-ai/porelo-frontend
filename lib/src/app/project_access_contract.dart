import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'bring_project_file.dart';
import 'host_access.dart' show HostAdminIdentity;
import 'host_access_contract.dart' show checkedRegistryRevision;
import 'machines.dart';
import 'registry.dart';
import 'run_here.dart';

/// Adapts the named Core commands while unserved trust and receipt reads stay in [ProjectAccessCore].
class ProjectAccessCoreAdapter {
  /// Uses the selected project's directory and an argument-list process runner.
  ProjectAccessCoreAdapter({required this.directory, RunHere? run}) : _run = run ?? runHere;

  /// The selected project's local working directory for Core's verification.
  final String directory;
  final RunHere _run;

  /// Files one idempotent change, using the verified presence of a persons access file.
  ///
  /// Registration initializes absent access or adds the admin on this host. Removal
  /// drops the person everywhere; locks apply to the whole project. Core owns ID
  /// deduplication. A stale base rereads verified state and requires a new decision.
  Future<String> file(ProjectAccessChange change, {required bool hasAccessFile}) async {
    // Constructors are public; validate even requests that did not come from stored receipts.
    checkAdminName(change.project);
    checkAdminName(change.actor);
    checkHostName(change.host);
    final person = change.action == 'register' ? change.actor : change.person?.login;
    if (person == null) throw const FormatException('Choose a project person.');
    checkAdminName(person);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(change.id)) {
      throw const FormatException('Invalid project request ID.');
    }
    if (!const ['register', 'add', 'remove', 'lock', 'unlock'].contains(change.action)) {
      throw const FormatException('Unknown project action.');
    }
    final action = change.action == 'register' ? (hasAccessFile ? 'add' : 'init') : change.action;
    if (action != 'init') checkedRegistryRevision(change.baseRevision);
    final result = await _run('porelo', [
      'project',
      'access',
      action,
      '--project',
      change.project,
      '--person',
      person,
      if (action == 'init' || action == 'add') ...['--host', change.host],
      if (action != 'init') ...['--base', change.baseRevision],
      '--id',
      change.id,
      '--json',
    ], inDirectory: directory);
    if (result.code == 65 && action != 'init') {
      final current = await verify(change.project);
      throw ProjectAccessConflict(change.baseRevision, current);
    }
    if (result.code != 0) throw const WorkspaceRefused('Core refused the project access change.');
    final revision = _object(result.out)['revision'];
    if (revision is! String) throw const FormatException('Core did not return an access revision.');
    return checkedRegistryRevision(revision);
  }

  /// Reads the persons-form verification in this selected project's directory.
  ///
  /// Keeps every named field, including revoked persons with empty SSH and expiry.
  /// Older access formats and roles outside `admin` and `developer` are refused.
  Future<Map<String, Object?>> verify(String project) async {
    checkAdminName(project);
    final result = await _run('porelo', ['project', 'verify', '--json'], inDirectory: directory);
    if (result.code != 0) throw const WorkspaceRefused('Core refused project verification.');
    final value = _object(result.out);
    if (value['project'] != project) throw const FormatException('The verified state names another project.');
    _revision(value['commit']);
    _revision(value['access_commit']);
    final persons = value['persons'];
    if (persons is! List) throw const FormatException('Core did not return persons-form access.');
    final logins = <String>{};
    final admins = <String>[];
    final checkedPersons = <Map<String, Object?>>[];
    for (final person in persons) {
      if (person is! Map<String, dynamic> ||
          person['login'] is! String ||
          person['ssh'] is! String ||
          person['expires'] is! String ||
          person['locked'] is! bool ||
          person['revoked'] is! bool) {
        throw const FormatException('Invalid verified project person.');
      }
      final login = person['login'] as String;
      checkAdminName(login);
      if (!logins.add(login)) throw const FormatException('Duplicate verified project person.');
      if (!const ['admin', 'developer'].contains(person['role'])) {
        throw const FormatException('Core returned an unsupported project role.');
      }
      final hosts = _strings(person['hosts']);
      for (final host in hosts) {
        checkHostName(host);
      }
      if (person['revoked'] == true) {
        if (person['ssh'] != '' || person['expires'] != '') {
          throw const FormatException('A revoked person must have empty SSH and expiry.');
        }
      } else {
        checkedEd25519(person['ssh'] as String);
        if ((person['expires'] as String).isEmpty) throw const FormatException('Missing person expiry.');
        if (person['role'] == 'admin' && person['locked'] == false) admins.add(login);
      }
      checkedPersons.add(Map.unmodifiable({...person, 'hosts': hosts}));
    }
    final answeredAdmins = _strings(value['admins']);
    if (jsonEncode(answeredAdmins) != jsonEncode(admins)) {
      throw const FormatException('Core returned inconsistent project admins.');
    }
    final signers = _strings(value['signers']);
    for (final signer in signers) {
      checkedEd25519(signer);
    }
    return Map.unmodifiable({
      ...value,
      'persons': List<Map<String, Object?>>.unmodifiable(checkedPersons),
      'admins': answeredAdmins,
      'certifiers': _strings(value['certifiers']),
      'signers': signers,
    });
  }

  static Map<String, dynamic> _object(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) throw const FormatException('Core did not return a JSON object.');
    return value;
  }

  static void _revision(Object? value) {
    if (value is! String) throw const FormatException('Missing verified project revision.');
    checkedRegistryRevision(value);
  }

  static List<String> _strings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Invalid verified project list.');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }
}

/// A stale access base requiring a fresh explicit decision, never an automatic retry.
class ProjectAccessConflict extends WorkspaceRefused {
  /// Retains the reread verified state for the next decision.
  ProjectAccessConflict(this.baseRevision, this.current)
    : super(
        'Access changed from $baseRevision to ${current['access_commit']}. Review the refreshed state and choose again.',
      );

  /// The refused base revision.
  final String baseRevision;

  /// Core's fresh verification, including the current access revision.
  final Map<String, Object?> current;
}

/// Core's current project-scoped card eligibility, including authorized key recovery.
class ProjectPersonVerdict {
  /// Retains only the fingerprint authorized for this access repository.
  const ProjectPersonVerdict(this.fingerprint, {this.replacedLostKey = false});

  /// The current authorized fingerprint.
  final String fingerprint;

  /// Whether Core accepted an admin's replacement in this project's access file.
  final bool replacedLostKey;
}

/// Core's verified source, admission, active signer set and access at one read.
class ProjectAccessView {
  /// Keeps trust decisions in Core rather than reproducing signature verification.
  ProjectAccessView({
    required this.project,
    required this.host,
    required this.projectRevision,
    required this.accessRevision,
    required this.projectYaml,
    required this.actor,
    required this.admittedFingerprint,
    required this.canAdmin,
    required this.signingAvailable,
    required List<String> adminSigners,
    required this.access,
    required Map<String, ProjectPersonVerdict> eligible,
    this.whoMay = const [],
  }) : adminSigners = List.unmodifiable(adminSigners),
       eligible = Map.unmodifiable(eligible);

  /// The verified followed project.
  final String project;

  /// The accepted, pinned SSH host card.
  final PreparedHost host;

  /// The verified project commit whose project.yml was read.
  final String projectRevision;

  /// The verified access commit on which a new edit must build.
  final String accessRevision;

  /// The project file from exactly [projectRevision].
  final String projectYaml;

  /// The current identity and key proven by Core.
  final HostAdminIdentity actor;

  /// The fingerprint pinned for the admitted project admin in `hosts/<host>/access.yml`.
  final String admittedFingerprint;

  /// Whether the current person is an active project admin, excluding backup keys.
  final bool canAdmin;

  /// Whether the current person's signing agent can sign this operation.
  final bool signingAvailable;

  /// The active project admins' public signing keys, excluding backup keys.
  final List<String> adminSigners;

  /// The accepted persons and their project locks.
  final AccessDevelopers access;

  /// The fingerprints Core permits for this project's picker.
  final Map<String, ProjectPersonVerdict> eligible;

  /// The permitted project admins with their available contact email.
  final List<RegistryContact> whoMay;

  /// The signed project's checked access address and repository inputs.
  BringProjectFile get source => BringProjectFile.read(projectYaml);
}

/// One immutable, idempotent project access edit or registration request.
class ProjectAccessChange {
  /// Retains the identity, scope and base commits selected before signing.
  const ProjectAccessChange({
    required this.id,
    required this.project,
    required this.host,
    required this.hostCard,
    required this.repository,
    required this.projectRevision,
    required this.baseRevision,
    required this.actor,
    required this.actorFingerprint,
    required this.action,
    this.person,
  });

  /// The durable request ID used to deduplicate Core's signing.
  final String id;

  /// The selected project, never a path.
  final String project;

  /// The selected registry host.
  final String host;

  /// The immutable host card selected before signing, including its SSH pin.
  final PreparedHost hostCard;

  /// The credential-free private access repository.
  final String repository;

  /// The exact signed project commit to register.
  final String projectRevision;

  /// The verified access parent; Core refuses concurrent edits.
  final String baseRevision;

  /// The current admin's login.
  final String actor;

  /// The admin key that authorized this request.
  final String actorFingerprint;

  /// `register`, `add`, `remove`, `lock` or `unlock`, always project scoped.
  final String action;

  /// The selected person and retained role, absent for registration.
  final AccessDeveloper? person;

  /// The single public request shape persisted for recovery and passed to Core.
  Map<String, Object?> get stored => {
    'id': id,
    'project': project,
    'host': host,
    'host_card': hostCard.stored,
    'access_repository': repository,
    'project_revision': projectRevision,
    'base_revision': baseRevision,
    'actor': actor,
    'actor_fingerprint': actorFingerprint,
    'action': action,
    if (person case final person?)
      'person': {
        'login': person.login,
        'role': person.role,
        'fingerprint': person.fingerprint,
        'locked': person.locked,
      },
  };

  /// Rejects corrupt or substituted scope before recovery can cause a side effect.
  factory ProjectAccessChange.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid pending project change.');
    String text(String key) {
      final field = value[key];
      if (field is! String || field.isEmpty) throw const FormatException('Incomplete project change.');
      return field;
    }

    final id = text('id');
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw const FormatException('Invalid project request ID.');
    final project = text('project');
    final host = text('host');
    final actor = text('actor');
    final hostCard = PreparedHost.read(value['host_card']);
    if (hostCard.name != host) throw const FormatException('The project host card names another host.');
    checkAdminName(project);
    checkHostName(host);
    checkAdminName(actor);
    final fingerprint = text('actor_fingerprint');
    AccessDeveloper(login: actor, role: 'admin', fingerprint: fingerprint);
    final repository = text('access_repository');
    BringProjectFile.checkSource(repository);
    // Access repositories must be remote, unlike followed project bundle sources.
    if (!repository.startsWith('https://') && !repository.startsWith('git@')) {
      throw const FormatException('A private access repository address is required.');
    }
    final action = text('action');
    if (!const ['register', 'add', 'remove', 'lock', 'unlock'].contains(action)) {
      throw const FormatException('Unknown project action.');
    }
    AccessDeveloper? person;
    final selected = value['person'];
    if (selected != null) {
      if (selected is! Map ||
          selected['login'] is! String ||
          selected['role'] is! String ||
          selected['fingerprint'] is! String ||
          selected['locked'] is! bool) {
        throw const FormatException('Invalid selected project person.');
      }
      person = AccessDeveloper(
        login: selected['login'] as String,
        role: selected['role'] as String,
        fingerprint: selected['fingerprint'] as String,
        locked: selected['locked'] as bool,
      );
    }
    if ((action == 'register') != (person == null)) throw const FormatException('Choose a project person.');
    return ProjectAccessChange(
      id: id,
      project: project,
      host: host,
      hostCard: hostCard,
      repository: repository,
      projectRevision: checkedRegistryRevision(text('project_revision')),
      baseRevision: checkedRegistryRevision(text('base_revision')),
      actor: actor,
      actorFingerprint: fingerprint,
      action: action,
      person: person,
    );
  }
}

/// Core reads and signs; Git publishes precisely the signed access commit.
abstract interface class ProjectAccessCore {
  /// Reads current identity, project trust, admission, signers and scoped eligibility.
  Future<ProjectAccessView> read(String project);

  /// Authorizes delivery of this exact published request using accepted signing-time authority.
  ///
  /// Returns current verified identity, project and admission only after confirming
  /// the accepted commit belongs to [change] and its originally authorized signer.
  /// This permits delivery of self-removal without granting authority to sign more
  /// changes. Current revoked identities or removed host admission still refuse it.
  Future<ProjectAccessView> delivery(ProjectAccessChange change, String revision);

  /// Resolves this request ID to Core's signed commit without signing or publishing.
  ///
  /// Returns `null` only when Core confirms that this ID was never filed. An
  /// unavailable lookup throws, so an uncertain receipt cannot be discarded.
  Future<String?> filedRevision(ProjectAccessChange change);

  /// Signs once per request ID and rejects stale parents or authorization.
  ///
  /// Edits only the selected person's entry, preserving unrelated access settings.
  /// Registration initializes absent persons access or adds the admin on the host.
  Future<String> file(ProjectAccessChange change);

  /// Checks whether this exact authorized request was already accepted by the remote.
  ///
  /// Reconciles a lost publication receipt without requiring authority for a new
  /// change. An unavailable remote throws; an unrelated commit is never accepted.
  Future<bool> publishedRevision(ProjectAccessChange change, String revision);

  /// Publishes this exact access commit without signing again.
  Future<void> publish(ProjectAccessChange change, String revision);
}

/// The host's observed project and access revisions and scoped memberships.
class ProjectAccessStatus {
  /// Retains the observed result rather than inferring success from process exit.
  const ProjectAccessStatus({
    required this.host,
    required this.project,
    required this.projectRevision,
    required this.accessRevision,
    required this.people,
  });

  /// The pinned host's name.
  final String host;

  /// The project the result belongs to.
  final String project;

  /// The applied project revision.
  final String projectRevision;

  /// The applied access revision.
  final String accessRevision;

  /// The project's confirmed person states: active or locked; removal means absence.
  final Map<String, String> people;
}

/// Own-account delivery through the pinned card's shared SSH tunnel.
abstract interface class ProjectAccessTransport {
  /// Opens the shared tunnel using the person's agent, without agent forwarding.
  Future<Machine> connect(ProjectAccessView view);

  /// Uploads the exact signed project/access bundles privately and confirms intake.
  ///
  /// The HostRun adapter stages owner-only files under
  /// `~/.local/share/porelo-host/setup/<project>/` and replaces them atomically.
  Future<void> upload(ProjectAccessChange change, String accessRevision);

  /// Registers or syncs that exact intake and reads its observed project state.
  Future<ProjectAccessStatus> apply(ProjectAccessChange change, String accessRevision);
}

/// The durable life of a project change, independent of publication retries.
enum ProjectAccessState {
  /// The request ID exists but Core's signed revision has not been resolved.
  unfiled,

  /// Core has signed the request and supplied its revision.
  filed,

  /// The host has uploaded and applied the exact revision and membership effect.
  delivered,

  /// Host delivery and any local registration recording have completed.
  confirmed,

  /// Current verified state has overtaken this signed request.
  superseded,
}

/// The immutable request and its last completed lifecycle and delivery stages.
class ProjectAccessProgress {
  /// Retains scope and receipts before the next side effect.
  const ProjectAccessProgress({
    required this.change,
    this.state = ProjectAccessState.unfiled,
    this.revision,
    this.published = false,
    this.uploaded = false,
  });

  /// The original request, including its idempotency ID.
  final ProjectAccessChange change;

  /// The durable lifecycle state.
  final ProjectAccessState state;

  /// Core's signed access revision, absent while unfiled.
  final String? revision;

  /// Whether the exact access commit was published.
  final bool published;

  /// Whether the exact bundles reached host intake.
  final bool uploaded;

  /// Whether delivery and local recording have completed.
  bool get confirmed => state == ProjectAccessState.confirmed;

  /// The public retry record; no credential or local key path is stored.
  Map<String, Object?> get stored => {
    'change': change.stored,
    'state': state.name,
    'revision': ?revision,
    'published': published,
    'uploaded': uploaded,
  };

  /// Refuses broken receipt ordering and migrates receipts predating explicit states.
  factory ProjectAccessProgress.read(Object? value) {
    if (value is! Map || value['published'] is! bool || value['uploaded'] is! bool) {
      throw const FormatException('Invalid project delivery progress.');
    }
    final revision = value['revision'];
    final ProjectAccessState state;
    if (value.containsKey('state')) {
      final parsed = ProjectAccessState.values.where((state) => state.name == value['state']).firstOrNull;
      if (parsed == null) throw const FormatException('Invalid project receipt state.');
      state = parsed;
    } else {
      if (value['confirmed'] is! bool) throw const FormatException('Invalid project delivery progress.');
      state = value['confirmed'] == true
          ? ProjectAccessState.confirmed
          : revision == null
          ? ProjectAccessState.unfiled
          : ProjectAccessState.filed;
    }
    if (revision != null && revision is! String ||
        (state == ProjectAccessState.unfiled) != (revision == null) ||
        value['published'] == true && revision == null ||
        value['uploaded'] == true && value['published'] != true ||
        (state == ProjectAccessState.delivered || state == ProjectAccessState.confirmed) && value['uploaded'] != true) {
      throw const FormatException('Invalid project delivery ordering.');
    }
    return ProjectAccessProgress(
      change: ProjectAccessChange.read(value['change']),
      state: state,
      revision: revision == null ? null : checkedRegistryRevision(revision as String),
      published: value['published'] as bool,
      uploaded: value['uploaded'] as bool,
    );
  }
}
