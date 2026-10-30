import 'dart:math';
import 'dart:convert';

import 'package:porelo_frontend/client.dart' show RegistryCard;
import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'project_access_contract.dart';
import 'project_developers.dart';
import 'registry.dart';
import 'settings.dart';
import 'signed_publication.dart';
import 'signed_host_actions.dart';
import 'machines.dart';

/// Registers and edits one project's verified access with durable host delivery.
class ProjectAccess implements ProjectPersonActions {
  /// Uses Core for trust and signing and the shared host tunnel for delivery.
  ProjectAccess({
    required this.project,
    required this.registry,
    required this.settings,
    required this.core,
    required this.transport,
  });

  /// The selected project, captured before any callback runs.
  final String project;

  /// The shared accepted registry and its card verdicts.
  final Registry registry;

  /// The shared durable receipts and mutation serialization.
  final Settings settings;

  /// Core's verified project and signed access boundary.
  final ProjectAccessCore core;

  /// The pinned own-account host delivery boundary.
  final ProjectAccessTransport transport;

  /// The latest verified project, retained for availability and contact words.
  ProjectAccessView? current;

  /// The pending exact access revision, absent once confirmed.
  String? get pendingRevision =>
      settings.projectAccess(project)?.confirmed == false ? settings.projectAccess(project)?.revision : null;

  /// Whether signed work still needs retry, even before a revision was received.
  @override
  bool get pending => settings.projectAccess(project)?.confirmed == false;

  /// Why the action is refused now, including the permitted admins and email.
  @override
  String? unavailable({bool delivery = false}) {
    final view = current;
    if (settings.projectChangeRunning(project)) return 'A change for this project is still running.';
    if (registry.accepted == null || registry.problem != null || registry.busy) {
      return 'Refresh the verified registry before changing this project.';
    }
    if (view == null) return 'Read the verified project admission first.';
    if (_reason(view, delivery: delivery && pending && settings.projectAccess(project)?.revision != null)
        case final reason?) {
      return _withContacts(reason, view);
    }
    return null;
  }

  /// The visible admission belonging to the selected verified project.
  @override
  String? get admission =>
      current != null && _reason(current!) == null ? 'Admitted on host ${current!.host.name}' : null;

  /// The registry cards Core permits for this project's access scope.
  @override
  List<RegistryCard> get candidates => [
    for (final card in registry.people)
      if (_eligible(current, card.login, card.fingerprint)) card,
  ];

  String _withContacts(String reason, ProjectAccessView view) {
    final contacts = view.whoMay
        .map((person) => '${person.name} (${person.login})${person.email == null ? '' : ', ${person.email}'}')
        .join('; ');
    return '$reason${contacts.isEmpty ? '' : ' Ask $contacts.'}';
  }

  String? _reason(ProjectAccessView view, {bool delivery = false}) {
    try {
      return _checkedReason(view, delivery: delivery);
    } on Exception {
      return 'Core did not supply a complete verified project and admission.';
    }
  }

  String? _checkedReason(ProjectAccessView view, {required bool delivery}) {
    if (view.project != project) return 'The verified state names another project.';
    if (!delivery && !view.canAdmin) return 'Only an active project admin may change this project.';
    if (!view.signingAvailable) return 'Unlock your signing agent before changing this project.';
    if (settings.hostReturned(view.host.name)) return 'The server was given back.';
    final actor = registry.selectable.where((person) => person.login == view.actor.login).firstOrNull;
    if (actor?.fingerprint != view.actor.fingerprint || view.admittedFingerprint != view.actor.fingerprint) {
      return 'Your current person card does not match the host admission.';
    }
    final host = registry.hosts.where((host) => host.host == view.host.name).firstOrNull;
    final admitted = host?.projects
        .where((entry) => entry.name == project && entry.admin == view.actor.login)
        .firstOrNull;
    if (admitted == null) return 'This project admin is not admitted on the selected host.';
    if (admitted.accessRepository != view.source.access) {
      return 'The access repository does not match the host admission.';
    }
    if (!delivery && (view.adminSigners.isEmpty || !view.adminSigners.contains(actor?.key))) {
      return 'Your current key is not an active project-admin signer.';
    }
    for (final key in view.adminSigners) {
      checkedEd25519(key);
    }
    return null;
  }

  Future<ProjectAccessView> _read() async {
    checkAdminName(project);
    final view = await core.read(project);
    current = view;
    return view;
  }

  Future<ProjectAccessView> _authorize([ProjectAccessChange? change, String? deliveryRevision]) async {
    final view = deliveryRevision == null ? await _read() : await core.delivery(change!, deliveryRevision);
    current = view;
    if (registry.accepted == null || registry.problem != null || registry.busy) {
      throw const RegistryRefusal('Refresh the verified registry before changing this project.');
    }
    if (_reason(view, delivery: deliveryRevision != null) case final reason?) {
      throw RegistryRefusal(_withContacts(reason, view), whoMay: view.whoMay);
    }
    if (change != null) {
      if (change.project != project ||
          change.host != view.host.name ||
          jsonEncode(change.hostCard.stored) != jsonEncode(view.host.stored) ||
          change.repository != view.source.access ||
          change.actor != view.actor.login ||
          change.actorFingerprint != view.actor.fingerprint ||
          change.projectRevision != view.projectRevision) {
        throw const RegistryRefusal(
          'The pending change no longer matches the verified identity, project or admission.',
        );
      }
      final revision = settings.projectAccess(project)?.revision;
      if (view.accessRevision != change.baseRevision && view.accessRevision != revision) {
        throw const RegistryRefusal(
          'Another access change was published. Resolve the pending revision before continuing.',
        );
      }
      if (change.action == 'add' && !_eligible(view, change.person!.login, change.person!.fingerprint)) {
        throw const RegistryRefusal('Core does not permit this person and key in this project.');
      }
    }
    return view;
  }

  bool _eligible(ProjectAccessView? view, String login, String fingerprint) {
    final verdict = view?.eligible[login];
    final card = registry.people.where((card) => card.login == login).firstOrNull;
    return verdict?.fingerprint == fingerprint &&
        card?.fingerprint == fingerprint &&
        (card?.trusted == true || verdict?.replacedLostKey == true);
  }

  @override
  Future<AccessDevelopers> read(String selectedProject) async {
    if (selectedProject != project) throw const RegistryRefusal('Choose this project.');
    return (await _read()).access;
  }

  /// Rechecks admission without starting publication, for a visible command.
  Future<ProjectAccessView> verify() => _authorize();

  @override
  Future<void> change(String selectedProject, AccessDeveloper person, {required bool remove}) async {
    if (selectedProject != project) throw const RegistryRefusal('Choose this project.');
    await _begin(remove ? 'remove' : 'add', person);
  }

  /// Registers only the selected admitted project with its verified revisions.
  Future<void> register() async {
    if (pending && settings.projectAccess(project)?.change.action == 'register') {
      await retry();
    } else {
      await _begin('register', null);
    }
  }

  @override
  Future<void> lock(String login, {required bool locked}) async {
    final view = await _read();
    final person = view.access.developers[login];
    if (person == null) throw const RegistryRefusal('Choose a person in this project.');
    await _begin(locked ? 'lock' : 'unlock', person);
  }

  Future<void> _begin(String action, AccessDeveloper? person) => settings.withProjectChange(project, () async {
    if (pending) throw const RegistryRefusal('Retry the pending project change before making another.');
    final view = await _authorize();
    if (action == 'add') {
      if (person!.role != 'developer' || person.locked || !_eligible(view, person.login, person.fingerprint)) {
        throw const RegistryRefusal('Core does not permit this person and key in this project.');
      }
      if (view.access.developers.containsKey(person.login)) {
        throw const RegistryRefusal('This person is already in the project.');
      }
    } else if (person != null) {
      final accepted = view.access.developers[person.login];
      if (accepted == null ||
          accepted.fingerprint != person.fingerprint ||
          accepted.role != person.role ||
          accepted.locked != person.locked) {
        throw const RegistryRefusal('Refresh the selected project person before changing access.');
      }
    }
    final random = Random.secure();
    final change = ProjectAccessChange.read(
      ProjectAccessChange(
        id: List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
        project: project,
        host: view.host.name,
        hostCard: view.host,
        repository: view.source.access,
        projectRevision: view.projectRevision,
        baseRevision: view.accessRevision,
        actor: view.actor.login,
        actorFingerprint: view.actor.fingerprint,
        action: action,
        person: person,
      ).stored,
    );
    await settings.rememberProjectAccess(ProjectAccessProgress(change: change));
    await _resume();
  });

  /// Resumes the original request after a restart without signing another change.
  @override
  Future<void> retry() => settings.withProjectChange(project, _resume);

  Future<void> _resume() async {
    var progress = settings.projectAccess(project);
    if (progress == null || progress.confirmed) return;
    final change = progress.change;
    final revision = await resumeSignedPublication(
      revision: progress.revision,
      published: progress.published,
      authorize: () async {
        await _authorize(change);
      },
      file: () => core.file(change),
      publish: (revision) => core.publish(change, revision),
      publishedAlready: (revision) => core.publishedRevision(change, revision),
      keep: (revision, published) async {
        progress = ProjectAccessProgress(change: change, revision: revision, published: published);
        await settings.rememberProjectAccess(progress!);
      },
    );
    final view = await _authorize(change, revision);
    final machine = await transport.connect(view);
    if (machine.kind != 'host' || machine.hostProject != change.host || machine.identity.isNotEmpty) {
      throw const RegistryRefusal('The shared tunnel did not confirm this host and person identity.');
    }
    await _authorize(change, revision);
    // Host intake may disappear on reboot; always upload again before applying.
    await transport.upload(change, revision);
    await settings.rememberProjectAccess(
      ProjectAccessProgress(change: change, revision: revision, published: true, uploaded: true),
    );
    await _authorize(change, revision);
    final answer = await transport.apply(change, revision);
    if (answer.host != change.host ||
        answer.project != project ||
        answer.projectRevision != change.projectRevision ||
        answer.accessRevision != revision) {
      throw const RegistryRefusal('The host did not confirm the intended project and access revisions.');
    }
    final expected = switch (change.action) {
      'add' || 'unlock' => 'active',
      'lock' => 'locked',
      _ => null,
    };
    final person = change.person?.login;
    if (expected != null && answer.people[person] != expected ||
        change.action == 'remove' && answer.people.containsKey(person)) {
      throw const RegistryRefusal('The host did not confirm this project membership change.');
    }
    await settings.rememberProjectAccess(
      ProjectAccessProgress(change: change, revision: revision, published: true, uploaded: true, confirmed: true),
    );
  }
}

/// Adapts durable registry registration to the shared register/join dialog boundary.
class RegistryProjectRegistration implements SignedHostActions {
  /// Keeps the selected project's access service.
  RegistryProjectRegistration(this.access);

  /// The project-scoped service shared with its person picker.
  final ProjectAccess access;

  @override
  Future<VerifiedHostProject> verify(String project, {required bool registering}) async {
    if (!registering || project != access.project) throw const RegistryRefusal('Choose the admitted project.');
    final view = await access.verify();
    return VerifiedHostProject(
      project: view.project,
      host: view.host,
      revision: view.projectRevision,
      adminSigners: view.adminSigners,
      admitted: true,
    );
  }

  @override
  Future<Machine> connect(VerifiedHostProject state) async {
    final view = await access.verify();
    if (view.host.name != state.host.name || view.projectRevision != state.revision) {
      throw const RegistryRefusal('The verified project admission changed.');
    }
    return access.transport.connect(view);
  }

  @override
  Future<String> register(VerifiedHostProject state, Machine machine) async {
    final view = await access.verify();
    if (state.project != access.project ||
        view.projectRevision != state.revision ||
        view.host.name != state.host.name ||
        machine.hostProject != view.host.name) {
      throw const RegistryRefusal('The verified project admission changed.');
    }
    await access.register();
    return access.settings.projectAccess(access.project)!.change.projectRevision;
  }

  @override
  Future<String> join(VerifiedHostProject state, Machine machine) =>
      throw const RegistryRefusal('Use the project joining operation.');
}
