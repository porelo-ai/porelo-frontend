import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart' show RegistryHost;
import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'bring_project_file.dart';
import 'host_access.dart' show HostAdminIdentity;
import 'host_access_contract.dart' show checkedRegistryRevision;
import 'identity.dart';
import 'key_recovery.dart' show cardFingerprint;
import 'project_access_contract.dart';
import 'project_copies.dart';
import 'registry.dart';
import 'run_here.dart';

/// One project as this computer follows it, read field by field from `porelo project following --json`.
class FollowedHere {
  /// Keeps the address, the commits in force and the keys pinned for the project.
  const FollowedHere({required this.url, required this.commit, required this.accessCommit, required this.signedBy});

  /// Where the project's repository is, as followed.
  final String url;

  /// The project commit in force here, `""` before any was.
  final String commit;

  /// The access commit in force here, `""` for none.
  final String accessCommit;

  /// The keys this computer pins for the project.
  final List<String> signedBy;
}

/// Core's verbs for a project's access, run on this computer as the person Core's identity names.
///
/// [read] verifies private copies of the followed project and its access repository with `porelo project verify`,
/// against the keys and commits this computer's follow holds in force, and joins Core's answer with the registry's
/// host admission and the person's card. Register and Add a developer are filed with `porelo project access
/// init|add`, which commits, signs through the agent and pushes in one step; publication then only reads the access
/// repository for that exact commit.
class CoreProjectAccess implements ProjectAccessCore {
  /// Takes the registry the pages read, the person's card, the private copies and an argument-list process runner.
  CoreProjectAccess({
    required this.registry,
    required this.identity,
    required this.copies,
    RunHere? run,
    this._agentKeys,
    String? Function(String project)? pinnedHost,
    bool Function(String host)? hostReturned,
    this.krl,
  }) : _run = run ?? runHere,
       _pinnedHost = pinnedHost ?? ((_) => null),
       _hostReturned = hostReturned ?? ((_) => false);

  /// What is said while no registry was chosen.
  static const noRegistry = 'Choose the registry repository first, so this project\'s hosts and persons can be read.';

  /// What is said for Remove, Lock and Let back in, which this interface does not send to Core yet.
  static const notConnected =
      'Removing, locking, letting back in and accepting a new key are not connected to Core and the host yet.';

  /// The registry the pages read, or null before one was chosen.
  final Registry? Function() registry;

  /// The person's card as Core's `identity show` answers it.
  final Future<IdentityCard> Function() identity;

  /// The private project and access copies Core verifies.
  final ProjectCopies copies;

  /// The revocation list Core's follow checks here, `~/.config/porelo/revoked.krl`; Core's `verify` and git are given it
  /// whenever it is there, as they read none of their own.
  final String? krl;

  final RunHere _run;
  final AgentKeys? _agentKeys;
  final String? Function(String project) _pinnedHost;
  final bool Function(String host) _hostReturned;

  // The last verification of each project, which filing builds on.
  final _last = <String, ({ProjectAccessCoreAdapter adapter, bool hasAccessFile})>{};

  @override
  Future<ProjectAccessView> read(String project) => _view(project);

  Future<ProjectAccessView> _view(String project, {String? accessAt}) async =>
      (await _verified(project, accessAt: accessAt)).view;

  // The view and Core's verified persons, refusals said in their own words.
  Future<({ProjectAccessView view, List<Map<String, Object?>> persons})> _verified(
    String project, {
    String? accessAt,
  }) async {
    try {
      return await _verifiedOnce(project, accessAt: accessAt);
    } on WorkspaceRefused catch (error) {
      throw RegistryRefusal(error.words);
    }
  }

  Future<({ProjectAccessView view, List<Map<String, Object?>> persons})> _verifiedOnce(
    String project, {
    String? accessAt,
  }) async {
    checkAdminName(project);
    final registry = this.registry();
    if (registry == null) throw const RegistryRefusal(noRegistry);
    final card = await _card();
    final followed = await _followed(project);
    final projectCopy = copies.project(project);
    await copies.fetch(projectCopy, followed.url);
    // Nothing is read from the project's newest commits before Core verified them: the access repository is the one
    // the project file names at the commit this computer's follow holds in force, as Core's own `access` takes it.
    if (followed.commit.isEmpty) {
      throw RegistryRefusal(
        'This computer follows $project without a verified commit yet. Refresh it, then read it again.',
      );
    }
    if (!await copies.holds(projectCopy, followed.commit)) {
      throw RegistryRefusal(
        'The repository of $project no longer holds the commit this computer follows. Refresh it, then read it again.',
      );
    }
    final named = _accessOf(await copies.show(projectCopy, followed.commit, 'project.yml'));
    final accessCopy = copies.access(project);
    await copies.fetch(accessCopy, named);
    var accessSince = followed.accessCommit.isEmpty ? null : followed.accessCommit;
    // A filed commit Core's follow took already, and maybe moved past, is in force here as it is.
    if (accessAt != null && accessSince != null && await copies.descends(accessCopy, accessSince, accessAt)) {
      accessSince = accessAt;
    }
    Directory? scratch;
    try {
      var accessSource = accessCopy;
      if (accessAt != null) {
        scratch = await HostFileWriter().createPrivateTemporary(Directory(copies.folder(project)));
        accessSource = path.join(scratch.path, 'access.bundle');
        await copies.bundle(accessCopy, accessAt, accessSource, scratch: scratch.path);
      }
      final adapter = ProjectAccessCoreAdapter(
        directory: copies.folder(project),
        run: _run,
        source: ProjectVerifySource(
          repository: projectCopy,
          signedBy: followed.signedBy,
          accessRepository: accessSource,
          since: followed.commit,
          accessSince: accessSince,
          krl: _krlHere(),
        ),
        agentKeys: _agentKeys,
      );
      final verified = await adapter.verify(project);
      final hasAccessFile = verified['access_commit'] != '';
      final projectRevision = verified['commit'] as String;
      final projectYaml = await copies.show(projectCopy, projectRevision, 'project.yml');
      if (_accessOf(projectYaml) != named) {
        throw const RegistryRefusal('The verified project names another access repository. Read it again.');
      }
      // An access repository holding no commit yet is one without an access file: its first commit has no base.
      final accessRevision = hasAccessFile ? verified['access_commit'] as String : await copies.head(accessCopy) ?? '';
      final host = _admittingHost(registry, project, card.login);
      final persons = (verified['persons'] as List).cast<Map<String, Object?>>();
      final admins = (verified['admins'] as List).cast<String>();
      final signers = (verified['signers'] as List).cast<String>();
      final ownKey = persons.where((person) => person['login'] == card.login).firstOrNull?['ssh'];
      final view = ProjectAccessView(
        project: project,
        host: host.card,
        projectRevision: projectRevision,
        accessRevision: accessRevision,
        projectYaml: projectYaml,
        actor: HostAdminIdentity(card.login, card.fingerprint),
        admittedFingerprint: host.entry.adminFingerprints[card.login] ?? '',
        // Core signs with the key it holds that this computer pins for the project: an admin's own key, or before any
        // access file a project signer's.
        canAdmin: hasAccessFile
            ? admins.contains(card.login) && ownKey == card.key && signers.contains(card.key)
            : signers.contains(card.key),
        signingAvailable: card.agent == AgentState.holds,
        adminSigners: hasAccessFile
            ? [
                for (final person in persons)
                  if (admins.contains(person['login']) && signers.contains(person['ssh'])) person['ssh'] as String,
              ]
            : signers,
        access: AccessDevelopers([
          for (final person in persons)
            if (person['revoked'] == false)
              AccessDeveloper(
                login: person['login'] as String,
                role: person['role'] as String,
                fingerprint: HostFiles.signingFingerprint(person['ssh'] as String),
                locked: person['locked'] as bool,
              ),
        ]),
        // The registry's trusted cards; Core refuses a card it does not take when the person is filed.
        eligible: {
          for (final person in registry.people)
            if (person.trusted) person.login: ProjectPersonVerdict(person.fingerprint),
        },
        // A name and an address are shown only from a card the registry trusts.
        whoMay: [
          for (final login in admins)
            if (registry.people.where((person) => person.login == login && person.trusted).firstOrNull
                case final person?)
              RegistryContact(login: login, name: person.name, email: person.contactEmail)
            else
              RegistryContact(login: login, name: login),
        ],
      );
      if (accessAt == null) _last[project] = (adapter: adapter, hasAccessFile: hasAccessFile);
      return (view: view, persons: persons);
    } finally {
      if (scratch != null && await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  String? _krlHere() => krl != null && File(krl!).existsSync() ? krl : null;

  static String _accessOf(String projectYaml) {
    try {
      return BringProjectFile.read(projectYaml).access;
    } on WorkspaceRefused catch (error) {
      throw RegistryRefusal(error.words);
    }
  }

  Future<IdentityCard> _card() async {
    final IdentityCard card;
    try {
      card = await identity();
    } on RegistryRefusal {
      rethrow;
    } on NoIdentity {
      throw const RegistryRefusal('Porelo knows no identity of yours yet, so no project access can be changed.');
    } on Object {
      throw const RegistryRefusal('Porelo\'s answer on your identity could not be read. Try again.');
    }
    // An agent that does not hold the key leaves the view readable and says so; a revoked or refused card does not.
    if (card.revoked || card.cardRefused != null) throw RegistryRefusal(card.whyKeyUnusable!);
    return card;
  }

  /// The one registry host whose access file admits [login] as [project]'s admin, with its accepted card: the host the
  /// project is registered on here when one is, never a host given back or one without an accepted card.
  ({RegistryHost entry, PreparedHost card}) _admittingHost(Registry registry, String project, String login) {
    final pinned = _pinnedHost(project);
    final hosts = [
      for (final host in registry.hosts)
        if (host.card != null &&
            !_hostReturned(host.host) &&
            (pinned == null || host.host == pinned) &&
            host.projects.any((entry) => entry.name == project && entry.admin == login))
          host,
    ];
    if (hosts.isEmpty) {
      throw RegistryRefusal(
        pinned == null
            ? 'No host in the registry admits you as the project admin of $project.'
            : 'Host $pinned, where $project is registered here, does not admit you as its project admin in the registry.',
      );
    }
    if (hosts.length > 1) {
      throw RegistryRefusal(
        'Several hosts admit you as the project admin of $project (${hosts.map((host) => host.host).join(', ')}); '
        'this interface registers on one.',
      );
    }
    try {
      return (entry: hosts.single, card: PreparedHost.card(hosts.single.card!));
    } on FormatException {
      throw RegistryRefusal('The registry\'s card of host ${hosts.single.host} could not be read.');
    }
  }

  Future<FollowedHere> _followed(String project) async {
    final Ran result;
    try {
      result = await _run('porelo', ['project', 'following', '--json']);
    } on Exception {
      throw const RegistryRefusal('Porelo could not be asked which projects this computer follows.');
    }
    if (result.code != 0) {
      throw const RegistryRefusal('Porelo could not say which projects this computer follows. Try again.');
    }
    final Object? answer;
    try {
      answer = jsonDecode(result.out);
    } on FormatException {
      throw const RegistryRefusal('Porelo\'s answer on the projects this computer follows could not be read.');
    }
    final follows = answer is Map ? answer['follows'] : null;
    if (follows is! List) {
      throw const RegistryRefusal('Porelo\'s answer on the projects this computer follows could not be read.');
    }
    final found = follows.where((follow) => follow is Map && follow['name'] == project).toList();
    if (found.isEmpty) throw RegistryRefusal('This computer does not follow $project, so its access cannot be read.');
    final follow = found.first as Map;
    final url = follow['url'];
    final commit = follow['commit'];
    final accessCommit = follow['access_commit'];
    final signedBy = follow['signed_by'];
    if (found.length != 1 ||
        url is! String ||
        url.isEmpty ||
        commit is! String ||
        accessCommit is! String ||
        follow['verified'] is! bool ||
        signedBy is! List ||
        signedBy.any((key) => key is! String)) {
      throw RegistryRefusal('Porelo\'s answer on how this computer follows $project could not be read.');
    }
    if (follow['verified'] != true || signedBy.isEmpty) {
      throw RegistryRefusal('This computer follows $project without a pinned key, so its access cannot be verified.');
    }
    return FollowedHere(
      url: url,
      commit: commit,
      accessCommit: accessCommit,
      signedBy: List.unmodifiable(signedBy.cast<String>()),
    );
  }

  @override
  Future<String> file(ProjectAccessChange change) async {
    if (change.action != 'register' && change.action != 'add') throw const RegistryRefusal(notConnected);
    final registry = this.registry();
    if (registry == null) throw const RegistryRefusal(noRegistry);
    _atRest(registry);
    var last = _last[change.project];
    if (last == null) {
      await read(change.project);
      last = _last[change.project]!;
    }
    final register = change.action == 'register';
    final login = register ? change.actor : change.person?.login;
    if (login == null) throw const RegistryRefusal('Choose a project person.');
    final fingerprint = register ? change.actorFingerprint : change.person!.fingerprint;
    final scratch = await HostFileWriter().createPrivateTemporary(Directory(copies.folder(change.project)));
    try {
      final card = await _acceptedCard(registry, login, fingerprint, into: scratch.path);
      return await last.adapter.file(change, hasAccessFile: last.hasAccessFile, card: card);
    } on RegistryRefusal {
      rethrow;
    } on WorkspaceRefused catch (error) {
      throw RegistryRefusal(error.words);
    } on FormatException catch (error) {
      throw RegistryRefusal(error.message);
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  /// Refuses while the registry is read, filed, held by a key change or not accepted as it stands.
  static void _atRest(Registry registry) {
    if (registry.held) throw const RegistryRefusal(Registry.heldWords);
    if (registry.busy) {
      throw const RegistryRefusal('A registry read or filing still runs; try again once it has ended.');
    }
    if (registry.accepted?.revision == null || registry.problem != null) {
      throw const RegistryRefusal('Refresh the verified registry before changing this project.');
    }
  }

  /// A private copy, in [into], of [login]'s card exactly as the registry's accepted commit holds it, never the
  /// checkout's working file, which a refresh or a key change may rewrite; refused unless it carries the reviewed key.
  Future<String> _acceptedCard(Registry registry, String login, String fingerprint, {required String into}) async {
    checkAdminName(login);
    final accepted = registry.accepted!;
    final text = await copies.blob(
      registry.checkout.folder,
      checkedRegistryRevision(accepted.revision!),
      'people/$login.card',
    );
    _atRest(registry);
    if (!identical(registry.accepted, accepted)) {
      throw const RegistryRefusal('The registry was read again meanwhile. Read the project again.');
    }
    if (cardFingerprint(text) != fingerprint) {
      throw RegistryRefusal(
        'The registry\'s accepted card of $login carries another key than the one chosen. Read the project again.',
      );
    }
    final copy = File(path.join(into, '$login.card'));
    await copy.create(exclusive: true);
    await HostFileWriter().protect(copy);
    await copy.writeAsString(text, flush: true);
    return copy.path;
  }

  @override
  Future<String?> filedRevision(ProjectAccessChange change) async {
    final copy = await _fetchedAccess(change);
    final found = await copies.changeCommits(copy, change.id);
    if (found.isEmpty) return null;
    if (found.length != 1 || await _adopted(change, copy, found.single) == null) {
      throw RegistryRefusal(
        'The access repository holds ${found.join(', ')} under this request\'s id, which is not the change made here. '
        'It was not taken.',
      );
    }
    return found.single;
  }

  @override
  Future<bool> publishedRevision(ProjectAccessChange change, String revision) async =>
      copies.holds(await _fetchedAccess(change), revision);

  /// Core pushed the commit when it filed it; this only confirms the access repository holds that exact commit.
  @override
  Future<void> publish(ProjectAccessChange change, String revision) async {
    if (!await publishedRevision(change, revision)) {
      throw ProjectAccessRetry('The access repository does not hold the filed commit $revision yet. Retry.');
    }
  }

  @override
  Future<ProjectAccessDelivery> delivery(ProjectAccessChange change, String revision) async {
    final copy = await _fetchedAccess(change);
    if (!await copies.holds(copy, revision)) {
      if (await copies.head(copy) case final head? when head != change.baseRevision) {
        return ProjectAccessRevisionOvertaken(change.id, revision);
      }
      throw ProjectAccessRetry('The access repository does not hold the filed commit $revision yet. Retry.');
    }
    final view = await _adopted(change, copy, revision);
    return view == null ? ProjectAccessRevisionRefused(change.id, revision) : ProjectAccessAuthorized(view);
  }

  /// The verified access at [revision] when it is this change's own commit, else null: made on the change's base
  /// alone, carrying its id once, signed by the actor's own key, verified by Core from the access commit in force
  /// here, and showing the person with the role and key the change names.
  Future<ProjectAccessView?> _adopted(ProjectAccessChange change, String copy, String revision) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(change.id)) return null;
    final parents = await copies.parents(copy, revision);
    final onItsBase = change.baseRevision.isEmpty
        ? parents.isEmpty
        : parents.length == 1 && parents.single == change.baseRevision;
    if (!onItsBase) return null;
    final ids = await copies.changeIds(copy, revision);
    if (ids.length != 1 || ids.single != change.id) return null;
    final (:view, :persons) = await _verified(change.project, accessAt: revision);
    if (view.accessRevision != revision) return null;
    final actorKey = persons
        .where(
          (person) =>
              person['login'] == change.actor &&
              person['revoked'] == false &&
              HostFiles.signingFingerprint(person['ssh'] as String) == change.actorFingerprint,
        )
        .firstOrNull?['ssh'];
    if (actorKey is! String) return null;
    final scratch = await HostFileWriter().createPrivateTemporary(Directory(copies.folder(change.project)));
    try {
      final allowed = File(path.join(scratch.path, 'allowed_signers'));
      await allowed.writeAsString('${change.actor} namespaces="git" $actorKey\n', flush: true);
      final signer = await copies.signer(copy, revision, allowedSigners: allowed.path, krl: _krlHere());
      if (signer != change.actorFingerprint) return null;
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
    final register = change.action == 'register';
    final shown = view.access.developers[register ? change.actor : change.person?.login];
    if (shown == null ||
        shown.locked ||
        shown.role != (register ? 'admin' : change.person!.role) ||
        shown.fingerprint != (register ? change.actorFingerprint : change.person!.fingerprint)) {
      return null;
    }
    return view;
  }

  Future<String> _fetchedAccess(ProjectAccessChange change) async {
    final copy = copies.access(change.project);
    try {
      await copies.fetch(copy, change.repository);
    } on RegistryRefusal catch (error) {
      throw ProjectAccessRetry(error.words);
    }
    return copy;
  }
}
