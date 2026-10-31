import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_model.dart';
import 'machines.dart';
import 'registry.dart' show RegistryRefusal;

/// The full access scope, retained when names match in different registries or hosts.
typedef RegistryTarget = ({String registry, String host, String? project});

/// An operation supplied by the registry, admission, access, or publishing adapter.
enum RegistryOperation {
  /// Refresh through its supplied adapter.
  refresh,

  /// File card through its supplied adapter.
  fileCard,

  /// Select registry through its supplied adapter.
  selectRegistry,

  /// Create registry through its supplied adapter.
  createRegistry,

  /// Admit through its supplied adapter.
  admit,

  /// Register through its supplied adapter.
  register,

  /// Add person through its supplied adapter.
  addPerson,

  /// Join through its supplied adapter.
  join,

  /// Project lock through its supplied adapter.
  projectLock,

  /// Project unlock through its supplied adapter.
  projectUnlock,

  /// Remove person through its supplied adapter.
  removePerson,

  /// Host lock through its supplied adapter.
  hostLock,

  /// Host unlock through its supplied adapter.
  hostUnlock,

  /// Delete account through its supplied adapter.
  deleteAccount,

  /// Take off host through its supplied adapter.
  takeOffHost,

  /// Bring state through its supplied adapter.
  bringState,

  /// Push through its supplied adapter.
  push,

  /// Pull through its supplied adapter.
  pull,

  /// Backup key through its supplied adapter.
  backupKey,

  /// Replace lost key through its supplied adapter.
  replaceLostKey,
}

/// The operations whose adapters have arrived; unsupported operations stay hidden here.
class RegistryPageFeatures {
  /// Creates a capability set from implemented adapters, never from a role alone.
  const RegistryPageFeatures({this.operations = const {}});

  /// The supplied backend operations.
  final Set<RegistryOperation> operations;

  /// Whether an operation has an adapter.
  bool supports(RegistryOperation operation) => operations.contains(operation);
}

/// A verified person card, with no key or secret value needed by a page.
@immutable
class RegistryPerson {
  /// Creates a card projection after its signature has been verified upstream.
  const RegistryPerson({required this.login, required this.name, this.email});

  /// The verified account login.
  final String login;

  /// The display name from the verified card.
  final String name;

  /// The optional public email address on the card.
  final String? email;

  /// A mail address safe to hand to a browser without headers or other URI parts.
  String? get contactEmail =>
      email != null && RegExp(r'^[^\s@?&#:]+@[^\s@?&#:]+\.[^\s@?&#:]+$').hasMatch(email!) ? email : null;
}

/// A person's registry role and the independently reported host state.
@immutable
class RegistryMember {
  /// Creates one person row.
  const RegistryMember({required this.person, required this.role, required this.state});

  /// The verified card for this row.
  final RegistryPerson person;

  /// The role reported by the registry.
  final String role;

  /// The state reported by the registry.
  final String state;
}

/// The role and verified contacts responsible for a particular operation.
typedef RegistryAuthority = ({String role, List<RegistryPerson> people});

/// One verified machine or project admission, independent of local following.
@immutable
class RegistryPageItem {
  /// Creates an item from the verified registry projection.
  const RegistryPageItem({
    required this.target,
    required this.machine,
    required this.role,
    required this.state,
    required this.revision,
    this.members = const [],
    this.administrators = const [],
    this.allowed = const {},
    this.roleOperations = const {},
    this.authorities = const {},
    this.refusals = const {},
  });

  /// The complete registry, host, and optional project identity.
  final RegistryTarget target;

  /// The machine this item belongs to.
  final Machine machine;

  /// The role reported by the registry.
  final String role;

  /// The state reported by the registry.
  final String state;

  /// The confirmed revision from this source.
  final String revision;

  /// The verified membership of this exact scope.
  final List<RegistryMember> members;

  /// The verified administrators who may change this scope.
  final List<RegistryPerson> administrators;

  /// The operations permitted by the verified access projection.
  final Set<RegistryOperation> allowed;

  /// The additional operations this person's role can hold, even when unavailable in this scope.
  final Set<RegistryOperation> roleOperations;

  /// The responsible role and contacts per operation, supplied by verified access.
  final Map<RegistryOperation, RegistryAuthority> authorities;

  /// Whether the operation belongs in this person's menu, independent of current availability.
  bool offers(RegistryOperation operation) => allowed.contains(operation) || roleOperations.contains(operation);

  /// The current operational refusals supplied by the adapter.
  final Map<RegistryOperation, String> refusals;
}

/// The host's confirmed applied revision and person states.
@immutable
class RegistryHostState {
  /// Creates a confirmed response without inferring it from publication.
  const RegistryHostState({required this.revision, this.personStates = const {}});

  /// The confirmed revision from this source.
  final String revision;

  /// The person states actually confirmed by the host.
  final Map<String, String> personStates;
}

/// The complete verified reference set returned by a registry adapter.
@immutable
class RegistryPageSnapshot {
  /// Creates a snapshot after all required access repositories have been read.
  const RegistryPageSnapshot({this.items = const [], this.people = const [], this.applied = const {}, this.problem});

  /// The last complete verified set of admissions.
  final List<RegistryPageItem> items;

  /// The verified person cards available to a picker.
  final List<RegistryPerson> people;

  /// The host confirmations kept separately from registry decisions.
  final Map<RegistryTarget, RegistryHostState> applied;

  /// Why a newer state is not the one in this snapshot, or null when it is the newest.
  final String? problem;
}

/// A scoped access change with a selected verified person, never a typed account.
typedef RegistryPageChange = ({RegistryTarget target, RegistryOperation operation, String? person});

/// The small boundary to verified registry data and separately confirmed host application.
abstract interface class RegistryPageSource {
  /// Reads the entire verified list, throwing when any required source cannot be read.
  Future<RegistryPageSnapshot> read();

  /// Publishes a permitted change and returns its confirmed registry revision.
  Future<String> publish(RegistryPageChange change);

  /// Brings a published revision to exactly its scope and returns the host's confirmation.
  Future<RegistryHostState> apply(RegistryTarget target, String revision);
}

/// Joins signed decisions and host confirmations without turning a pending change into success.
class RegistryPages extends ChangeNotifier {
  /// Creates page state with optional adapters; the default exposes no unavailable protocol.
  RegistryPages({this.source, this.features = const RegistryPageFeatures(), this._address});

  final String? Function()? _address;

  /// The chosen registry's address, or null when none is chosen.
  String? get address => _address?.call();

  /// The verified-state adapter, absent until its protocol is supplied.
  final RegistryPageSource? source;

  /// The operations whose adapters are available.
  final RegistryPageFeatures features;
  RegistryPageSnapshot _snapshot = const RegistryPageSnapshot();
  final Map<RegistryTarget, String> _published = {};
  final Map<RegistryTarget, RegistryHostState> _applied = {};
  final Map<RegistryTarget, String> _failures = {};

  /// Whether an adapter operation is still in progress.
  bool busy = false;

  /// The public explanation of the latest failed read.
  String? problem;

  /// Whether a complete verified read has succeeded.
  bool loaded = false;

  /// The last complete verified set of admissions.
  List<RegistryPageItem> get items => _snapshot.items;

  /// The verified person cards available to a picker.
  List<RegistryPerson> get people => _snapshot.people;

  /// Looks up the full identity, never just its project name.
  RegistryPageItem? item(RegistryTarget target) => items.where((item) => item.target == target).firstOrNull;

  /// Reads a project's admission on its specific machine.
  RegistryPageItem? project(Machine machine, String project) {
    final matches = projectAdmissions(machine, project);
    return matches.length == 1 ? matches.single : null;
  }

  /// All registry scopes for a machine's project, without choosing the first registry.
  List<RegistryPageItem> projectAdmissions(Machine machine, String project) => items
      .where(
        (item) =>
            item.machine.name == machine.name &&
            item.machine.socketPath == machine.socketPath &&
            item.target.project == project,
      )
      .toList();

  /// Reads a host only when its registry identity is unambiguous.
  RegistryPageItem? host(Machine machine) {
    final matches = items
        .where(
          (item) =>
              item.machine.name == machine.name &&
              item.machine.socketPath == machine.socketPath &&
              item.target.project == null,
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  /// The registry's confirmed decision revision, including a published but unapplied change.
  String? decidedRevision(RegistryTarget target) => _published[target] ?? item(target)?.revision;

  /// The last revision actually confirmed by the host.
  RegistryHostState? applied(RegistryTarget target) => _applied[target] ?? _snapshot.applied[target];

  /// The latest application failure for this item.
  String? failure(RegistryTarget target) => _failures[target];

  /// Whether the decision still needs host confirmation.
  bool pending(RegistryTarget target) => decidedRevision(target) != applied(target)?.revision;

  /// A permission or adapter refusal, rechecked immediately before mutation.
  String? unavailable(RegistryTarget target, RegistryOperation operation, {String? person}) {
    if (busy) return 'Another registry operation is still running.';
    if (!features.supports(operation) || source == null) return 'This operation is not available yet.';
    if (problem != null) return 'Refresh the verified access state before making a change.';
    final current = item(target);
    if (current == null) return 'No verified access state is available for this item.';
    if (!current.allowed.contains(operation)) {
      final authority = current.authorities[operation];
      final who = (authority?.people ?? <RegistryPerson>[])
          .map((person) => '${person.name} (${person.login}; ${person.contactEmail ?? 'no email supplied'})')
          .join(', ');
      final role =
          authority?.role ??
          switch (operation) {
            RegistryOperation.admit ||
            RegistryOperation.hostLock ||
            RegistryOperation.hostUnlock ||
            RegistryOperation.deleteAccount => 'a host admin',
            RegistryOperation.register ||
            RegistryOperation.addPerson ||
            RegistryOperation.projectLock ||
            RegistryOperation.projectUnlock ||
            RegistryOperation.removePerson => 'a project admin',
            RegistryOperation.createRegistry => 'a registry owner',
            _ => null,
          };
      if (role == null) {
        return 'The verified access state has not supplied the responsible role or contacts for this operation.';
      }
      return 'Only $role may do this${who.isEmpty ? '; no verified contacts for this operation were supplied' : ': $who'}.';
    }
    if (current.refusals[operation] case final refusal?) return refusal;
    if (person != null && !people.any((card) => card.login == person)) return 'Choose a verified person card.';
    if (_memberOperations.contains(operation) && !current.members.any((member) => member.person.login == person)) {
      return 'This person is not in the selected access list.';
    }
    if (target.project == defaultProject &&
        {
          RegistryOperation.takeOffHost,
          RegistryOperation.projectLock,
          RegistryOperation.projectUnlock,
          RegistryOperation.removePerson,
        }.contains(operation)) {
      return 'Without a project is always available on this machine.';
    }
    return null;
  }

  static const _memberOperations = {
    RegistryOperation.projectLock,
    RegistryOperation.projectUnlock,
    RegistryOperation.removePerson,
    RegistryOperation.hostLock,
    RegistryOperation.hostUnlock,
    RegistryOperation.deleteAccount,
    RegistryOperation.replaceLostKey,
  };

  int _generation = 0;
  Future<void>? _reading;

  /// Refreshes without discarding the last verified list on an unreadable source.
  Future<void> refresh() {
    if (source == null) return Future<void>.value();
    if (busy) return _reading ?? Future<void>.value();
    return _reading = _read();
  }

  /// Forgets everything read so far and reads again, for a source that now reads another registry.
  ///
  /// A read still running for the earlier registry ends unseen, so its state never shows under this one.
  Future<void> readAfresh() async {
    _generation++;
    _snapshot = const RegistryPageSnapshot();
    _published.clear();
    _applied.clear();
    _failures.clear();
    loaded = false;
    _readFor = null;
    problem = null;
    notifyListeners();
    await _reading;
    await refresh();
  }

  String? _readFor;

  /// Whether the lists shown were read from the address chosen now, not from one chosen before.
  bool get loadedForAddress => loaded && _readFor == address;

  Future<void> _read() async {
    final generation = _generation;
    final reading = address;
    busy = true;
    notifyListeners();
    try {
      final next = await source!.read();
      if (generation != _generation) return;
      final nextItems = {for (final item in next.items) item.target: item};
      _published.removeWhere(
        (target, revision) =>
            nextItems[target] == null ||
            nextItems[target]!.revision == revision ||
            nextItems[target]!.revision != item(target)?.revision,
      );
      _applied.removeWhere(
        (target, state) =>
            nextItems[target] == null ||
            (next.applied[target] != null && next.applied[target]!.revision != _snapshot.applied[target]?.revision),
      );
      _snapshot = next;
      _failures.removeWhere((target, _) => item(target) == null || !pending(target));
      problem = next.problem;
      loaded = true;
      _readFor = reading;
    } on RegistryRefusal catch (refused) {
      if (generation == _generation) problem = refused.words;
    } on Exception {
      if (generation == _generation) {
        problem = 'The verified registry or access repository could not be read. The last verified list is retained.';
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Publishes to the exact target and changes applied state only on host confirmation.
  Future<void> change(RegistryPageChange change) async {
    final reason = unavailable(change.target, change.operation, person: change.person);
    if (reason != null) throw StateError(reason);
    if (change.operation == RegistryOperation.refresh) {
      await refresh();
      return;
    }
    busy = true;
    _failures.remove(change.target);
    notifyListeners();
    try {
      final revision = await source!.publish(change);
      if (revision.isEmpty) throw const FormatException('The registry returned no revision.');
      _published[change.target] = revision;
      notifyListeners();
      try {
        final confirmation = await source!.apply(change.target, revision);
        if (confirmation.revision != revision) throw const FormatException('The host confirmed a different revision.');
        _applied[change.target] = confirmation;
      } on Exception {
        _failures[change.target] = 'Published in the registry; the host has not confirmed this change.';
      }
    } on Exception {
      _failures[change.target] = 'The change was not confirmed by the registry.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

/// Includes each machine's permanent default before the daemon's first project response.
List<ProjectOnScreen> projectsOnMachine(Machines machines, Machine machine, {RegistryPages? registry}) {
  final local = machines.all.contains(machine) ? machines.of(machine).projects : <ProjectOnScreen>[];
  final projects = <String, ProjectOnScreen>{for (final project in local) project.name: project};
  projects.putIfAbsent(
    defaultProject,
    () => ProjectOnScreen(project: Project.from({'name': defaultProject}), tasks: const []),
  );
  for (final item in registry?.items ?? <RegistryPageItem>[]) {
    if (item.machine.name != machine.name || item.machine.socketPath != machine.socketPath) continue;
    final name = item.target.project;
    if (name != null) {
      projects.putIfAbsent(name, () => ProjectOnScreen(project: Project.from({'name': name}), tasks: const []));
    }
  }
  return projects.values.toList();
}

/// The union of watched machines and machines with verified admissions.
List<Machine> registryMachines(Machines machines, RegistryPages? registry) {
  final all = <Machine>[...machines.all];
  final local = Machine.local();
  if (!all.any((machine) => machine.socketPath == local.socketPath && !machine.needsATunnel)) all.add(local);
  for (final item in registry?.items ?? <RegistryPageItem>[]) {
    if (!all.any((machine) => machine.name == item.machine.name && machine.socketPath == item.machine.socketPath)) {
      all.add(item.machine);
    }
  }
  return all;
}

/// One project row whose registry identity is never reduced to its display name.
typedef RegistryProjectRow = ({Machine machine, ProjectOnScreen project, RegistryPageItem? admission});

/// Projects on a machine with a distinct row for each verified registry admission.
List<RegistryProjectRow> scopedProjectRows(Machines machines, Machine machine, {RegistryPages? registry}) => [
  for (final project in projectsOnMachine(machines, machine, registry: registry))
    if (project.name == defaultProject || (registry?.projectAdmissions(machine, project.name).isEmpty ?? true))
      (machine: machine, project: project, admission: null)
    else
      for (final admission in registry!.projectAdmissions(machine, project.name))
        (machine: machine, project: project, admission: admission),
];

/// The full row identity, using registry scope whenever an admission supplied it.
String projectRowIdentity(Machine machine, String project, RegistryPageItem? admission) =>
    admission == null ? '${machine.name}/$project' : '${admission.target.registry}/${admission.target.host}/$project';

/// A machine row with its full host admission, when the registry supplied one.
typedef RegistryMachineRow = ({Machine machine, RegistryPageItem? admission});

/// Machines retain separate rows when different registries name the same host.
List<RegistryMachineRow> scopedMachineRows(Machines machines, RegistryPages? registry) => [
  for (final machine in registryMachines(machines, registry))
    if (!(registry?.items.any(
          (item) =>
              item.machine.name == machine.name &&
              item.machine.socketPath == machine.socketPath &&
              item.target.project == null,
        ) ??
        false))
      (machine: machine, admission: null)
    else
      for (final admission in registry!.items.where(
        (item) =>
            item.machine.name == machine.name &&
            item.machine.socketPath == machine.socketPath &&
            item.target.project == null,
      ))
        (machine: machine, admission: admission),
];
