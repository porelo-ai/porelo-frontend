import 'dart:math';
import 'dart:convert';

import 'package:porelo_frontend/client.dart' show RegistryCard;
import 'package:porelo_host/porelo_host.dart';

import 'access_developers.dart';
import 'project_access_contract.dart';
import 'host_access_contract.dart' show checkedRegistryRevision;
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
    required this.rememberMachine,
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

  /// The idempotent Machine recording operation shared by registration and Retry.
  final Future<void> Function(Machine machine) rememberMachine;

  /// The latest verified project, retained for availability and contact words.
  ProjectAccessView? current;

  /// The pending exact access revision, absent once confirmed.
  String? get pendingRevision =>
      settings.projectAccess(project)?.confirmed == false ? settings.projectAccess(project)?.revision : null;

  /// Whether signed work still needs retry, even before a revision was received.
  @override
  bool get pending => settings.projectAccess(project)?.confirmed == false;

  /// The exact superseded request offered for explicit discard.
  @override
  String? get supersededChangeId => settings.projectAccess(project)?.state == ProjectAccessState.superseded
      ? settings.projectAccess(project)?.change.id
      : null;

  /// Forgets only the superseded receipt selected by the control.
  @override
  Future<void> discard(String changeId) =>
      settings.withProjectChange(project, () => settings.forgetSupersededProjectAccess(project, changeId));

  static const _superseded = 'This project change was superseded. Discard it before making another change.';

  String get _supersededReason => settings.projectAccessReason(project) ?? _superseded;

  static const _signingUnavailable = 'Unlock your signing agent before changing this project.';
  static const _incomplete = 'Core did not supply a complete verified project and admission.';

  Future<T> _withChange<T>(Future<T> Function() work) async {
    late T result;
    await settings.withProjectChange(project, () async {
      result = await work();
    });
    return result;
  }

  /// Why the action is refused now, including the permitted admins and email.
  @override
  String? unavailable({bool delivery = false}) {
    final view = current;
    if (settings.projectChangeRunning(project)) return 'A change for this project is still running.';
    if (supersededChangeId != null) return _supersededReason;
    // Recovery must resolve uncertain receipts before it can check mutation authority.
    if (delivery && pending) return null;
    if (registry.accepted == null || registry.problem != null || registry.busy) {
      return 'Refresh the verified registry before changing this project.';
    }
    if (view == null) return 'Read the verified project admission first.';
    if (_reason(view) case final reason?) {
      return _withContacts(reason, view);
    }
    return null;
  }

  /// The visible admission belonging to the selected verified project.
  @override
  String? get admission =>
      _registryReady && current != null && _reason(current!) == null ? 'Admitted on host ${current!.host.name}' : null;

  /// The registry cards Core permits for this project's access scope.
  @override
  List<RegistryCard> get candidates => [
    if (_registryReady && current != null && _reason(current!) == null)
      for (final card in registry.people)
        if (_eligible(current, card.login, card.fingerprint)) card,
  ];

  String _withContacts(String reason, ProjectAccessView view) =>
      RegistryRefusal(reason, whoMay: _contacts(view)).toString();

  List<RegistryContact> _contacts(ProjectAccessView view) {
    if (view.project != project || !view.signingAvailable || settings.hostReturned(view.host.name)) return [];
    final host = registry.hosts.where((host) => host.host == view.host.name).firstOrNull;
    final admission = host?.projects
        .where((entry) => entry.name == project && entry.admin == view.actor.login)
        .firstOrNull;
    final actor = registry.selectable.where((card) => card.login == view.actor.login).firstOrNull;
    final hostIssue =
        view.canAdmin &&
        (admission == null ||
            admission.accessRepository != view.source.access ||
            actor?.fingerprint != view.actor.fingerprint ||
            view.admittedFingerprint != view.actor.fingerprint);
    final logins = hostIssue ? host?.admins ?? <String>[] : [for (final person in view.whoMay) person.login];
    return [
      for (final login in {...logins})
        for (final card in registry.selectable.where((card) => card.login == login))
          RegistryContact(login: login, name: card.name, email: card.contactEmail),
    ];
  }

  String? _reason(ProjectAccessView view, {bool delivery = false}) {
    try {
      return _checkedReason(view, delivery: delivery);
    } on Exception {
      return _incomplete;
    }
  }

  String? _checkedReason(ProjectAccessView view, {required bool delivery}) {
    if (view.project != project) return 'The verified state names another project.';
    if (!delivery && !view.canAdmin) return 'Only an active project admin may change this project.';
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
    if (!view.signingAvailable) return _signingUnavailable;
    for (final key in view.adminSigners) {
      checkedEd25519(key);
    }
    return null;
  }

  Future<ProjectAccessView> _read() async {
    current = null;
    checkAdminName(project);
    if (!_registryReady) throw const RegistryRefusal('Refresh the verified registry before changing this project.');
    final view = await core.read(project);
    if (!_registryReady) throw const RegistryRefusal('Refresh the verified registry before changing this project.');
    if (view.project != project) throw const RegistryRefusal('The verified state names another project.');
    current = view;
    return view;
  }

  Future<ProjectAccessView> _authorize({ProjectAccessProgress? receipt, VerifiedHostProject? expected}) async {
    current = null;
    if (receipt?.state == ProjectAccessState.superseded) throw RegistryRefusal(_supersededReason);
    final filed = receipt?.revision != null;
    final delivered = receipt?.state == ProjectAccessState.delivered;
    if (filed && settings.hostReturned(receipt!.change.host)) {
      await _supersede(receipt, _SupersessionReason.hostReturned);
    }
    var view = await _read();
    if (filed && !_matches(receipt!.change, view, recording: delivered)) {
      throw RegistryRefusal(
        'The pending project selection differs from the verified state. Retry.',
        whoMay: _contacts(view),
      );
    }
    if (filed && receipt!.state != ProjectAccessState.delivered) {
      current = null;
      final verdict = await core.delivery(receipt.change, receipt.revision!);
      switch (verdict) {
        case ProjectAccessAuthorized(:final view):
          current = view;
        case ProjectAccessRevisionRefused(:final changeId, :final revision):
          await _deliveryRefused(receipt, changeId, revision, _SupersessionReason.coreRefused);
        case ProjectAccessRevisionOvertaken(:final changeId, :final revision):
          await _deliveryRefused(receipt, changeId, revision, _SupersessionReason.overtaken);
      }
      view = current!;
      if (view.accessRevision != receipt.revision) {
        throw const RegistryRefusal('Core did not authorize the filed project access revision. Retry.');
      }
    }
    await _checkView(view, receipt: receipt, delivery: filed);
    if (expected != null) {
      if (receipt != null) _checkRegistrationChange(expected, receipt.change);
      _checkRegistration(expected, view, delivery: filed, delivered: delivered);
    }
    return view;
  }

  Future<void> _checkView(ProjectAccessView view, {ProjectAccessProgress? receipt, required bool delivery}) async {
    if (!_registryReady) throw const RegistryRefusal('Refresh the verified registry before changing this project.');
    final change = receipt?.change;
    final recording = receipt?.state == ProjectAccessState.delivered;
    if (change != null) {
      if (!_matches(change, view, recording: recording) ||
          !recording && view.accessRevision != change.baseRevision && view.accessRevision != receipt!.revision) {
        throw RegistryRefusal(
          'The pending project selection differs from the verified state. Retry.',
          whoMay: _contacts(view),
        );
      }
    }
    if (_reason(view, delivery: delivery) case final reason?) {
      throw RegistryRefusal(reason, whoMay: _contacts(view));
    }
    if (!delivery &&
        change != null &&
        (change.action == 'add' || change.action == 'unlock') &&
        !_eligible(view, change.person!.login, change.person!.fingerprint)) {
      throw const RegistryRefusal('Core does not permit this person and key in this project.');
    }
  }

  bool _matches(ProjectAccessChange change, ProjectAccessView view, {bool recording = false}) =>
      change.project == project &&
      view.project == project &&
      change.host == view.host.name &&
      jsonEncode(change.hostCard.stored) == jsonEncode(view.host.stored) &&
      change.repository == view.source.access &&
      change.actor == view.actor.login &&
      change.actorFingerprint == view.actor.fingerprint &&
      (recording || change.projectRevision == view.projectRevision);

  Future<Never> _deliveryRefused(
    ProjectAccessProgress receipt,
    String changeId,
    String revision,
    _SupersessionReason reason,
  ) async {
    if (changeId != receipt.change.id || revision != receipt.revision) {
      throw const RegistryRefusal('Core judged another project filing. Retry this receipt.');
    }
    await _supersede(receipt, reason);
  }

  Future<Never> _supersede(ProjectAccessProgress receipt, _SupersessionReason reason) async {
    if (receipt.state == ProjectAccessState.filed) {
      await settings.rememberProjectAccess(
        ProjectAccessProgress(
          change: receipt.change,
          revision: receipt.revision,
          state: ProjectAccessState.superseded,
          published: receipt.published,
          uploaded: receipt.uploaded,
        ),
        reason: reason.words,
      );
    }
    throw RegistryRefusal(reason.words);
  }

  Future<ProjectAccessProgress> _resolve(ProjectAccessProgress receipt) async {
    if (receipt.state != ProjectAccessState.unfiled) return receipt;
    final revision = await core.filedRevision(receipt.change);
    if (revision == null) return receipt;
    final filed = ProjectAccessProgress(
      change: receipt.change,
      revision: checkedRegistryRevision(revision),
      state: ProjectAccessState.filed,
    );
    await settings.rememberProjectAccess(filed);
    return filed;
  }

  Future<String> _file(ProjectAccessProgress receipt) async {
    try {
      return await core.file(receipt.change);
    } on Exception {
      await _resolve(receipt);
      rethrow;
    }
  }

  bool get _registryReady => registry.accepted != null && registry.problem == null && !registry.busy;

  bool _eligible(ProjectAccessView? view, String login, String fingerprint) {
    if (!_registryReady || view?.project != project) return false;
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
  Future<ProjectAccessView> verify() => _withChange(() async {
    final receipt = await _reconcile();
    return receipt == null ? _authorize() : current!;
  });

  @override
  Future<void> change(String selectedProject, AccessDeveloper person, {required bool remove}) async {
    if (selectedProject != project) throw const RegistryRefusal('Choose this project.');
    await _begin(remove ? 'remove' : 'add', person);
  }

  /// Registers only the selected admitted project with its verified revisions.
  Future<void> register({VerifiedHostProject? expected}) async {
    await _begin('register', null, expected: expected);
  }

  void _checkRegistrationChange(VerifiedHostProject expected, ProjectAccessChange change) {
    if (expected.project != change.project ||
        expected.revision != change.projectRevision ||
        jsonEncode(expected.host.stored) != jsonEncode(change.hostCard.stored)) {
      throw const RegistryRefusal('The pending receipt differs from the verified project admission.');
    }
  }

  void _checkRegistration(
    VerifiedHostProject expected,
    ProjectAccessView view, {
    bool delivery = false,
    bool delivered = false,
  }) {
    if (expected.project != project ||
        view.project != project ||
        !delivered && expected.revision != view.projectRevision ||
        jsonEncode(expected.host.stored) != jsonEncode(view.host.stored) ||
        !delivery && jsonEncode(expected.adminSigners) != jsonEncode(view.adminSigners)) {
      throw const RegistryRefusal('The verified project admission changed.');
    }
  }

  @override
  Future<void> lock(String login, {required bool locked, AccessDeveloper? selected}) async {
    final person = selected ?? current?.access.developers[login];
    await _begin(locked ? 'lock' : 'unlock', person);
  }

  Future<void> _begin(
    String action,
    AccessDeveloper? person, {
    VerifiedHostProject? expected,
    Machine? registrationMachine,
  }) => _withChange(() async {
    final pendingReceipt = await _reconcile();
    if (registrationMachine != null && registrationMachine.hostProject != expected!.host.name) {
      throw const RegistryRefusal('The verified project admission changed.');
    }
    if (pendingReceipt != null) {
      if (action == 'register' && pendingReceipt.change.action == 'register') {
        await _continue(pendingReceipt, expected: expected);
        return;
      }
      await _authorize(receipt: pendingReceipt, expected: expected);
      throw const RegistryRefusal('Retry the pending project change before making another.');
    }
    if ((action == 'lock' || action == 'unlock') && person == null) {
      throw const RegistryRefusal('Choose a person in this project.');
    }
    final view = await _authorize(expected: expected);
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
    if (action == 'unlock' && !_eligible(view, person!.login, person.fingerprint)) {
      throw const RegistryRefusal('Core does not permit this person and key in this project.');
    }
    if ((action == 'lock' || action == 'unlock') && person!.locked == (action == 'lock')) {
      throw const RegistryRefusal('Refresh the selected project person before changing access.');
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
    final receipt = ProjectAccessProgress(change: change);
    await settings.rememberProjectAccess(receipt);
    await _continue(receipt, expected: expected);
  });

  /// Resumes the original request after a restart without signing another change.
  @override
  Future<void> retry() => _withChange(_resume);

  Future<ProjectAccessProgress?> _reconcile() async {
    var progress = settings.projectAccess(project);
    if (progress == null || progress.confirmed) return null;
    if (progress.state == ProjectAccessState.superseded) throw RegistryRefusal(_supersededReason);
    progress = await _resolve(progress);
    if (progress.state == ProjectAccessState.unfiled) {
      await settings.forgetUnfiledProjectAccess(project);
      return null;
    }
    await _authorize(receipt: progress);
    return progress;
  }

  Future<void> _resume() async {
    final progress = await _reconcile();
    if (progress != null) await _continue(progress);
  }

  Future<void> _continue(ProjectAccessProgress receipt, {VerifiedHostProject? expected}) async {
    ProjectAccessProgress? progress = receipt;
    final change = receipt.change;
    if (receipt.state == ProjectAccessState.delivered) {
      if (change.action == 'register') {
        final view = await _authorize(receipt: receipt, expected: expected);
        await _recordRegistration(await transport.connect(view), change);
      }
      await _confirm(receipt);
      return;
    }
    final revision = await resumeSignedPublication(
      revision: progress.revision,
      published: progress.published,
      authorize: () async {
        await _authorize(receipt: progress, expected: expected);
      },
      file: () => _file(progress!),
      publish: (revision) => core.publish(change, revision),
      publishedAlready: (revision) => core.publishedRevision(change, revision),
      keep: (revision, published) async {
        progress = ProjectAccessProgress(
          change: change,
          revision: revision,
          state: ProjectAccessState.filed,
          published: published,
        );
        await settings.rememberProjectAccess(progress!);
      },
    );
    final view = await _authorize(receipt: progress, expected: expected);
    final machine = await transport.connect(view);
    if (machine.kind != 'host' || machine.hostProject != change.host || machine.identity.isNotEmpty) {
      throw const RegistryRefusal('The shared tunnel did not confirm this host and person identity.');
    }
    await _authorize(receipt: progress, expected: expected);
    // Host intake may disappear on reboot; always upload again before applying.
    await transport.upload(change, revision);
    progress = ProjectAccessProgress(
      change: change,
      revision: revision,
      state: progress!.state,
      published: true,
      uploaded: true,
    );
    await settings.rememberProjectAccess(progress!);
    await _authorize(receipt: progress, expected: expected);
    final answer = await transport.apply(change, revision);
    if (answer.host != change.host ||
        answer.project != project ||
        answer.projectRevision != change.projectRevision ||
        answer.accessRevision != revision) {
      throw const RegistryRefusal('The host did not confirm the intended project and access revisions.');
    }
    final expectedPersonState = switch (change.action) {
      'add' || 'unlock' => 'active',
      'lock' => 'locked',
      _ => null,
    };
    final person = change.person?.login;
    if (expectedPersonState != null && answer.people[person] != expectedPersonState ||
        change.action == 'remove' && answer.people.containsKey(person)) {
      throw const RegistryRefusal('The host did not confirm this project membership change.');
    }
    await settings.rememberProjectAccess(
      ProjectAccessProgress(
        change: change,
        revision: revision,
        state: ProjectAccessState.delivered,
        published: true,
        uploaded: true,
      ),
    );
    if (change.action == 'register') await _recordRegistration(machine, change);
    await _confirm(settings.projectAccess(project)!);
  }

  Future<void> _confirm(ProjectAccessProgress receipt) => settings.rememberProjectAccess(
    ProjectAccessProgress(
      change: receipt.change,
      revision: receipt.revision,
      state: ProjectAccessState.confirmed,
      published: true,
      uploaded: true,
    ),
  );

  List<String> _registrationSigners(ProjectAccessView view) {
    final receipt = settings.projectAccess(project);
    if (receipt?.revision == null || receipt!.confirmed || receipt.change.action != 'register') {
      return view.adminSigners;
    }
    // Core authorized the filed signer; current admin status governs only new signing.
    return [
      for (final card in registry.selectable)
        if (card.login == receipt.change.actor && card.fingerprint == receipt.change.actorFingerprint) card.key,
    ];
  }

  Future<void> _recordRegistration(Machine machine, ProjectAccessChange change) async {
    if (machine.kind != 'host' || machine.hostProject != change.host || machine.identity.isNotEmpty) {
      throw const RegistryRefusal('The shared tunnel did not confirm this host and person identity.');
    }
    await rememberMachine(machine);
    await settings.rememberProjectHost(project, change.host);
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
    final view = await access.verify();
    if (!registering || project != access.project) throw const RegistryRefusal('Choose the admitted project.');
    final receipt = access.settings.projectAccess(project);
    return VerifiedHostProject(
      project: view.project,
      host: view.host,
      revision: receipt?.state == ProjectAccessState.delivered ? receipt!.change.projectRevision : view.projectRevision,
      adminSigners: access._registrationSigners(view),
      admitted: true,
    );
  }

  @override
  Future<Machine> connect(VerifiedHostProject state) => access._withChange(() async {
    final receipt = await access._reconcile();
    final view = receipt == null ? await access._authorize() : access.current!;
    if (receipt != null) access._checkRegistrationChange(state, receipt.change);
    access._checkRegistration(
      state,
      view,
      delivery: receipt?.revision != null,
      delivered: receipt?.state == ProjectAccessState.delivered,
    );
    return access.transport.connect(view);
  });

  @override
  Future<String> register(VerifiedHostProject state, Machine machine) async {
    await access._begin('register', null, expected: state, registrationMachine: machine);
    return state.revision;
  }

  @override
  Future<String> join(VerifiedHostProject state, Machine machine) =>
      throw const RegistryRefusal('Use the project joining operation.');
}

enum _SupersessionReason {
  coreRefused,
  overtaken,
  hostReturned;

  String get words => switch (this) {
    coreRefused => 'Core refuses authorization of this exact filed project access revision. Discard it.',
    overtaken => 'The verified access revision moved past this receipt without containing it. Discard it.',
    hostReturned => 'The server was given back.',
  };
}
