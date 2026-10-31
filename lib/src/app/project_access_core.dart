import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart' show RegistryHost;
import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'bring_project_file.dart';
import 'host_access.dart' show HostAdminIdentity;
import 'identity.dart';
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
  }) : _run = run ?? runHere;

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

  final RunHere _run;
  final AgentKeys? _agentKeys;

  // The last verification of each project, which filing builds on.
  final _last = <String, ({ProjectAccessCoreAdapter adapter, bool hasAccessFile})>{};

  @override
  Future<ProjectAccessView> read(String project) => _view(project);

  Future<ProjectAccessView> _view(String project, {String? accessAt}) async {
    checkAdminName(project);
    final registry = this.registry();
    if (registry == null) throw const RegistryRefusal(noRegistry);
    final card = await _card();
    final followed = await _followed(project);
    final projectCopy = copies.project(project);
    await copies.fetch(projectCopy, followed.url);
    final named = _accessOf(await copies.show(projectCopy, 'HEAD', 'project.yml'));
    final accessCopy = copies.access(project);
    await copies.fetch(accessCopy, named);
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
          since: followed.commit.isEmpty ? null : followed.commit,
          // An exact filed commit is checked on its own: the access in force here may have moved past it already.
          accessSince: accessAt != null || followed.accessCommit.isEmpty ? null : followed.accessCommit,
        ),
        registryCheckout: registry.checkout.folder,
        agentKeys: _agentKeys,
      );
      final verified = await adapter.verify(project);
      final hasAccessFile = verified['access_commit'] != '';
      final projectRevision = verified['commit'] as String;
      final projectYaml = await copies.show(projectCopy, projectRevision, 'project.yml');
      if (_accessOf(projectYaml) != named) {
        throw const RegistryRefusal('The verified project names another access repository. Read it again.');
      }
      final accessRevision = hasAccessFile ? verified['access_commit'] as String : await copies.head(accessCopy);
      if (accessRevision == null) {
        throw RegistryRefusal(
          'The access repository $named holds no commit yet. Its first commit, signed by a project signer, comes '
          'before the project can be registered.',
        );
      }
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
        whoMay: [
          for (final login in admins)
            RegistryContact(
              login: login,
              name: registry.people.where((person) => person.login == login).firstOrNull?.name ?? login,
              email: registry.people.where((person) => person.login == login).firstOrNull?.contactEmail,
            ),
        ],
      );
      if (accessAt == null) _last[project] = (adapter: adapter, hasAccessFile: hasAccessFile);
      return view;
    } finally {
      if (scratch != null && await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

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

  /// The one registry host whose access file admits [login] as [project]'s admin, with its accepted card.
  static ({RegistryHost entry, PreparedHost card}) _admittingHost(Registry registry, String project, String login) {
    final hosts = [
      for (final host in registry.hosts)
        if (host.projects.any((entry) => entry.name == project && entry.admin == login)) host,
    ];
    if (hosts.isEmpty) {
      throw RegistryRefusal('No host in the registry admits you as the project admin of $project.');
    }
    if (hosts.length > 1) {
      throw RegistryRefusal(
        'Several hosts admit you as the project admin of $project (${hosts.map((host) => host.host).join(', ')}); '
        'this interface registers on one.',
      );
    }
    final card = hosts.single.card;
    if (card == null) throw RegistryRefusal('The registry holds no accepted card of host ${hosts.single.host} yet.');
    try {
      return (entry: hosts.single, card: PreparedHost.card(card));
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
    var last = _last[change.project];
    if (last == null) {
      await read(change.project);
      last = _last[change.project]!;
    }
    try {
      return await last.adapter.file(change, hasAccessFile: last.hasAccessFile);
    } on RegistryRefusal {
      rethrow;
    } on WorkspaceRefused catch (error) {
      throw RegistryRefusal(error.words);
    } on FormatException catch (error) {
      throw RegistryRefusal(error.message);
    }
  }

  @override
  Future<String?> filedRevision(ProjectAccessChange change) async {
    final copy = await _fetchedAccess(change);
    return copies.changeCommit(copy, change.id);
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
    if (!(await copies.changeIds(copy, revision)).contains(change.id)) {
      return ProjectAccessRevisionRefused(change.id, revision);
    }
    return ProjectAccessAuthorized(await _view(change.project, accessAt: revision));
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
