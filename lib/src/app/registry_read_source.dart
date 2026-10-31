import 'package:porelo_frontend/client.dart';

import 'machines.dart';
import 'registry.dart';
import 'registry_pages.dart';

/// The pages' view of Core's accepted registry read, the one source of every registry list.
///
/// Only the read and Refresh are served here; a change reaches the registry through the adapters that
/// own it, so [publish] and [apply] refuse.
class RegistryReadSource implements RegistryPageSource, RegistryCheckouts {
  /// Constructor taking the chosen address, how a registry is opened for it, and the watched machines.
  RegistryReadSource({required this.repository, required this.open, required this.machines});

  /// The registry's address as chosen now, or null before it was; part of every target.
  final String? Function() repository;

  /// Opens the registry of an address, once per address, so another address never shows this one's state.
  final Registry Function(String repository) open;

  /// The machines watched here; a host the person does not watch has no machine to show it on yet.
  final List<Machine> Function() machines;

  // One registry per address, and so per checkout folder: going to another address and back finds the one a run may
  // hold, never a second, unheld one on the same folder.
  final _opened = <String, Registry>{};

  // The token every registry opened here is held by for a change Core makes in each, or null.
  Object? _allHolder;

  /// The registry of the address chosen now, or null before one was chosen.
  Registry? get registry {
    final address = repository();
    if (address == null) return null;
    return _opened[address] ??= _opening(address);
  }

  Registry _opening(String address) {
    final made = open(address);
    // Opened while a change Core makes in every checkout runs: held for it from the start.
    if (_allHolder case final holder?) made.hold(holder);
    return made;
  }

  @override
  List<Registry> holdAll(Object holder) {
    if (_allHolder != null) throw const RegistryRefusal(Registry.heldWords);
    final held = <Registry>[];
    try {
      for (final each in _opened.values) {
        each.hold(holder);
        held.add(each);
      }
    } on RegistryRefusal {
      for (final each in held) {
        each.release(holder);
      }
      rethrow;
    }
    _allHolder = holder;
    return List.unmodifiable(_opened.values);
  }

  @override
  void releaseAll(Object holder) {
    if (!identical(_allHolder, holder)) return;
    _allHolder = null;
    for (final each in _opened.values) {
      each.release(holder);
    }
  }

  @override
  Future<RegistryPageSnapshot> read() async {
    final registry = this.registry;
    if (registry == null) throw const RegistryRefusal('Choose the registry repository first.');
    await registry.refresh();
    final accepted = registry.accepted;
    if (accepted == null) throw RegistryRefusal(registry.problem ?? 'No accepted registry is available yet.');
    return snapshotOf(registry.checkout.repository, accepted, problem: registry.problem);
  }

  /// The pages' snapshot of [accepted] from [repository]; [problem] says why a newer state is not the one shown.
  RegistryPageSnapshot snapshotOf(String repository, RegistryRead accepted, {String? problem}) {
    final trusted = {
      for (final card in accepted.people)
        if (card.trusted) card.login: RegistryPerson(login: card.login, name: card.name, email: card.contactEmail),
    };
    RegistryPerson person(String login) => trusted[login] ?? RegistryPerson(login: login, name: login);
    final owners = [
      for (final owner in accepted.owners)
        if (!owner.backup) person(owner.login),
    ];
    final watched = machines();
    final items = <RegistryPageItem>[];
    for (final host in accepted.hosts) {
      final machine = watched.where((machine) => machine.host == host.host).firstOrNull;
      if (machine == null) continue;
      final admins = [for (final login in host.admins) person(login)];
      final authority = (role: 'a host admin', people: admins.isEmpty ? owners : admins);
      items.add(
        RegistryPageItem(
          target: (registry: repository, host: host.host, project: null),
          machine: machine,
          role: '',
          state: 'admitted',
          revision: accepted.revision!,
          administrators: admins,
          allowed: const {RegistryOperation.refresh},
          authorities: {for (final operation in _hostOperations) operation: authority},
        ),
      );
      for (final project in host.projects) {
        items.add(
          RegistryPageItem(
            target: (registry: repository, host: host.host, project: project.name),
            machine: machine,
            role: '',
            state: 'admitted',
            revision: accepted.revision!,
            members: [RegistryMember(person: person(project.admin), role: 'project admin', state: 'admitted')],
            administrators: [person(project.admin)],
            allowed: const {RegistryOperation.refresh},
            authorities: {
              for (final operation in _projectOperations)
                operation: (role: 'a project admin', people: [person(project.admin)]),
            },
          ),
        );
      }
    }
    return RegistryPageSnapshot(items: items, people: trusted.values.toList(), problem: problem);
  }

  static const _hostOperations = {
    RegistryOperation.admit,
    RegistryOperation.hostLock,
    RegistryOperation.hostUnlock,
    RegistryOperation.deleteAccount,
  };

  static const _projectOperations = {
    RegistryOperation.register,
    RegistryOperation.addPerson,
    RegistryOperation.projectLock,
    RegistryOperation.projectUnlock,
    RegistryOperation.removePerson,
  };

  @override
  Future<String> publish(RegistryPageChange change) =>
      Future.error(const RegistryRefusal('This change is not made through the registry read.'));

  @override
  Future<RegistryHostState> apply(RegistryTarget target, String revision) =>
      Future.error(const RegistryRefusal('This change is not made through the registry read.'));
}
