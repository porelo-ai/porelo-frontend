import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'bring_project_file.dart';
import 'host_access.dart' show HostAdminIdentity;
import 'host_access_contract.dart' show checkedRegistryRevision;
import 'machines.dart';
import 'registry.dart';
import 'run_here.dart';

/// The public keys the person's SSH agent holds, as `ssh-ed25519 AAAA...` without comments.
typedef AgentKeys = Future<List<String>> Function();

/// The local project copies and pinned keys Core's `project verify` checks, never a secret.
class ProjectVerifySource {
  /// Takes the project repository, the keys this machine pins for it and its access repository copy.
  ProjectVerifySource({required this.repository, required List<String> signedBy, this.accessRepository})
    : signedBy = List.unmodifiable(signedBy);

  /// The project repository as a local path or bundle.
  final String repository;

  /// The keys this machine pins for the project, each `ssh-ed25519 AAAA...`.
  final List<String> signedBy;

  /// The access repository as a local path or bundle, absent for a project naming none.
  final String? accessRepository;
}

/// Whether a login may change this project's access here, from Core's verified admins and the agent's keys.
class ProjectAdminStanding {
  /// Keeps both halves of the check and the admins to ask otherwise.
  ProjectAdminStanding({required this.admin, required this.holdsPinnedKey, required List<String> admins})
    : admins = List.unmodifiable(admins);

  /// Reads the standing from a checked `project verify` answer and the agent's public keys.
  factory ProjectAdminStanding.of(Map<String, Object?> verified, String login, Iterable<String> agentKeys) {
    final admins = (verified['admins'] as List).cast<String>();
    final signers = (verified['signers'] as List).cast<String>().toSet();
    return ProjectAdminStanding(
      admin: admins.contains(login),
      holdsPinnedKey: agentKeys.any(signers.contains),
      admins: admins,
    );
  }

  /// Whether the login is among the admins neither locked nor revoked.
  final bool admin;

  /// Whether the agent holds a key this machine pins for the project.
  final bool holdsPinnedKey;

  /// The active project admins, in access-file order.
  final List<String> admins;

  /// Whether a project access change may be sent at all.
  bool get may => admin && holdsPinnedKey;

  /// The active admins as contacts; names and addresses are filled from registry cards by the caller.
  List<RegistryContact> get whoMay => [for (final login in admins) RegistryContact(login: login, name: login)];
}

/// A project access change refused before any command, because the actor is no project admin here.
class ProjectAccessNotAdmin extends RegistryRefusal {
  /// Names what is missing and who may instead.
  ProjectAccessNotAdmin(this.standing)
    : super(
        standing.admin
            ? 'Your SSH agent holds no key this machine pins for the project.'
            : 'Only an active project admin may change this project.',
        whoMay: standing.whoMay,
      );

  /// The standing that refused the change.
  final ProjectAdminStanding standing;
}

/// Core's refusal of a filing other than a stale base, by exit code and with its typed reason where given.
class ProjectAccessFilingRefused extends WorkspaceRefused {
  /// Keeps the exit code and Core's typed reason; the words are safe to show.
  const ProjectAccessFilingRefused(this.code, super.words, {this.reason});

  /// Core's exit code: 64 wrong use, 65 refused, 66 not followed or not reached, 69 push failed.
  final int code;

  /// Core's fixed kebab-case reason, when its answer named one.
  final String? reason;
}

/// Adapts the named Core commands while unserved trust and receipt reads stay in [ProjectAccessCore].
class ProjectAccessCoreAdapter {
  /// Uses the selected project's directory and an argument-list process runner.
  ProjectAccessCoreAdapter({
    required this.directory,
    RunHere? run,
    this._delivery,
    this.source,
    this.registryCheckout,
    this._agentKeys,
  }) : _run = run ?? runHere;

  /// The selected project's local working directory for Core's verification.
  final String directory;

  /// The project copies and pinned keys `project verify` checks; verification is refused without them.
  final ProjectVerifySource? source;

  /// The accepted registry checkout whose `people/LOGIN.card` Core takes as `--card`.
  final String? registryCheckout;

  final RunHere _run;
  final ProjectAccessDeliveryCheck? _delivery;
  final AgentKeys? _agentKeys;

  /// Reads the exact filing verdict through the supplied Core trust boundary.
  Future<ProjectAccessDelivery> delivery(ProjectAccessChange change, String revision) async {
    final read = _delivery;
    if (read == null) throw const ProjectAccessRetry('Core delivery verification is unavailable. Retry.');
    return _retryOnFailure(() => read(change, revision));
  }

  static Future<T> _retryOnFailure<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on WorkspaceRefused {
      throw const ProjectAccessRetry('Core verification is unavailable or refused. Retry.');
    } on FormatException {
      throw const ProjectAccessRetry('Core verification is incomplete or unsupported. Retry.');
    } on RegistryRefusal {
      throw const ProjectAccessRetry('Core verification is unavailable or refused. Retry.');
    }
  }

  /// Whether [login] is project admin here: an active admin whose key the agent holds and this machine pins.
  Future<ProjectAdminStanding> standing(String project, {required String login}) async {
    checkAdminName(login);
    final verified = await verify(project);
    final keys = await _retryOnFailure(_agentKeys ?? _listAgentKeys);
    return ProjectAdminStanding.of(verified, login, keys);
  }

  Future<List<String>> _listAgentKeys() async {
    final listed = await _run(openSsh('ssh-add'), ['-L']);
    // ssh-add answers 1 for an agent holding no key, which holds no pinned key either.
    if (listed.code == 1) return const [];
    if (listed.code != 0) throw const WorkspaceRefused('The SSH agent could not be asked for its keys.');
    return [
      for (final line in const LineSplitter().convert(listed.out))
        if (line.trim().isNotEmpty) line.trim().split(RegExp(r'\s+')).take(2).join(' '),
    ];
  }

  String _card(String login) {
    final checkout = registryCheckout;
    if (checkout == null || checkout.isEmpty) {
      throw const FormatException('The registry checkout holding the person card is unknown.');
    }
    return path.join(checkout, 'people', '$login.card');
  }

  /// Files one idempotent change, using the verified presence of a persons access file.
  ///
  /// Registration initializes absent access or adds the admin on this host. Removal
  /// drops the person everywhere; locks apply to the whole project; a replacement puts
  /// the person's new registry card in. Every action but `init` is sent only for an
  /// active admin whose key the agent holds. Core owns ID deduplication. A stale base
  /// rereads verified state and requires a new decision.
  Future<String> file(ProjectAccessChange change, {required bool hasAccessFile}) async {
    // Constructors are public; validate even requests that did not come from stored receipts.
    checkAdminName(change.project);
    checkAdminName(change.actor);
    checkHostName(change.host);
    final register = change.action == 'register';
    final person = register ? change.actor : change.person?.login;
    if (person == null) throw const FormatException('Choose a project person.');
    checkAdminName(person);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(change.id)) {
      throw const FormatException('Invalid project request ID.');
    }
    if (!projectAccessActions.contains(change.action)) {
      throw const FormatException('Unknown project action.');
    }
    final action = register ? (hasAccessFile ? 'add' : 'init') : change.action;
    if (action != 'init') checkedRegistryRevision(change.baseRevision);
    final role = action == 'add' ? (register ? 'admin' : change.person!.role) : null;
    if (role != null && !const ['admin', 'developer'].contains(role)) {
      throw const FormatException('Unknown project role.');
    }
    final card = const ['init', 'add', 'replace'].contains(action) ? _card(person) : null;
    if (action != 'init') {
      final standing = await this.standing(change.project, login: change.actor);
      if (!standing.may) throw ProjectAccessNotAdmin(standing);
    }
    final result = await _run('porelo', [
      'project',
      'access',
      action,
      '--project',
      change.project,
      '--person',
      person,
      if (action == 'init' || action == 'add') ...['--host', change.host],
      if (card != null) ...['--card', card],
      if (role != null) ...['--role', role],
      if (action != 'init') ...['--base', change.baseRevision],
      '--id',
      change.id,
      '--json',
    ], inDirectory: directory);
    if (result.code == 65 && action != 'init') {
      final current = await verify(change.project);
      if (current['access_commit'] != change.baseRevision) throw ProjectAccessConflict(change.baseRevision, current);
    }
    if (result.code != 0) throw _refused(result);
    final revision = _object(result.out)['revision'];
    if (revision is! String) throw const FormatException('Core did not return an access revision.');
    return checkedRegistryRevision(revision);
  }

  static ProjectAccessFilingRefused _refused(Ran result) {
    String? reason;
    String? words;
    try {
      final typed = _object(result.out);
      if (typed['reason'] case final String named when RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(named)) {
        reason = named;
        if (typed['words'] case final String said when said.trim().isNotEmpty) words = said.trim();
      }
    } on FormatException {
      // An untyped refusal keeps the fixed words of its exit code.
    }
    return ProjectAccessFilingRefused(
      result.code,
      words ??
          switch (result.code) {
            64 => 'Core refused the project access request as wrong use.',
            65 => 'Core refused the project access change.',
            66 => 'The project is not followed here, or its access repository was not reached. Retry.',
            69 => 'The project access change could not be pushed. Retry; the same request answers the same revision.',
            _ => 'Core could not make the project access change.',
          },
      reason: reason,
    );
  }

  /// Reads the persons-form verification in this selected project's directory.
  ///
  /// Keeps every named field, including revoked persons with empty SSH and expiry.
  /// Older access formats and roles outside `admin` and `developer` are refused.
  Future<Map<String, Object?>> verify(String project) => _retryOnFailure(() => _verify(project));

  Future<Map<String, Object?>> _verify(String project) async {
    checkAdminName(project);
    final source = this.source;
    if (source == null || source.repository.isEmpty || source.signedBy.isEmpty) {
      throw const FormatException('The project copy and its pinned keys are unknown.');
    }
    for (final key in source.signedBy) {
      checkedEd25519(key);
    }
    final result = await _run('porelo', [
      'project',
      'verify',
      '--repository',
      source.repository,
      for (final key in source.signedBy) ...['--signed-by', key],
      '--project',
      project,
      if (source.accessRepository case final access?) ...['--access-repository', access],
      '--json',
    ], inDirectory: directory);
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

/// A Core read failure that retains the receipt for Retry.
class ProjectAccessRetry extends RegistryRefusal {
  /// Retains safe public words without dependency diagnostics.
  const ProjectAccessRetry(super.words);
}

/// The unserved Core boundary for an exact filed request's delivery verdict.
typedef ProjectAccessDeliveryCheck = Future<ProjectAccessDelivery> Function(
  ProjectAccessChange change,
  String revision,
);

/// Core's typed verdict on the exact filed request, independent of refusal words.
sealed class ProjectAccessDelivery {
  const ProjectAccessDelivery();
}

/// Core authorizes this request using its signing-time authority.
class ProjectAccessAuthorized extends ProjectAccessDelivery {
  /// Retains the verified state at the filed access revision.
  const ProjectAccessAuthorized(this.view);

  /// The verified delivery state, including current identity and admission.
  final ProjectAccessView view;
}

/// Core explicitly refuses authorization of this exact filed revision.
class ProjectAccessRevisionRefused extends ProjectAccessDelivery {
  /// Pins the refusal to the request and signed revision Core judged.
  const ProjectAccessRevisionRefused(this.changeId, this.revision);

  /// The judged durable request ID.
  final String changeId;

  /// The judged filed access revision.
  final String revision;
}

/// Core verified that access moved past the base without containing this filing.
class ProjectAccessRevisionOvertaken extends ProjectAccessDelivery {
  /// Pins the verified exclusion to the request and signed revision.
  const ProjectAccessRevisionOvertaken(this.changeId, this.revision);

  /// The judged durable request ID.
  final String changeId;

  /// The excluded filed access revision.
  final String revision;
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

/// The project-scoped actions a [ProjectAccessChange] names; `replace` accepts a person's new key.
const projectAccessActions = ['register', 'add', 'remove', 'lock', 'unlock', 'replace'];

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

  /// One of [projectAccessActions], always project scoped.
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
    if (!projectAccessActions.contains(action)) throw const FormatException('Unknown project action.');
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
  /// Returns [ProjectAccessAuthorized] with identity, project and admission only
  /// after confirming the commit belongs to [change] and its original signer.
  /// Only [ProjectAccessRevisionRefused] and [ProjectAccessRevisionOvertaken],
  /// pinned to the exact request ID and revision, supersede filed work. A newer
  /// head containing the filing is still authorized; read failures throw
  /// [ProjectAccessRetry] without discarding it.
  /// This permits delivery of self-removal without granting authority to sign more
  /// changes. Current revoked identities or removed host admission still refuse it.
  Future<ProjectAccessDelivery> delivery(ProjectAccessChange change, String revision);

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
