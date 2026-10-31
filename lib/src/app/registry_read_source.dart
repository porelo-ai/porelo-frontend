import 'package:porelo_frontend/client.dart';

import 'machines.dart';
import 'registry.dart';
import 'registry_pages.dart';

/// The pages' view of Core's accepted registry read, the one source of every registry list.
///
/// Only the read and Refresh are served here; a change reaches the registry through the adapters that
/// own it, so [publish] and [apply] refuse.
class RegistryReadSource implements RegistryPageSource {
  /// Constructor taking the shared registry and the watched machines a host is matched against.
  RegistryReadSource({required this.registry, required this.repository, required this.machines});

  /// The shared registry, whose last accepted read is shown.
  final Registry registry;

  /// The registry's address, part of every target so two registries never share one.
  final String repository;

  /// The machines watched here; a host the person does not watch has no machine to show it on yet.
  final List<Machine> Function() machines;

  @override
  Future<RegistryPageSnapshot> read() async {
    await registry.refresh();
    final accepted = registry.accepted;
    if (accepted == null) throw RegistryRefusal(registry.problem ?? 'No accepted registry is available yet.');
    return snapshotOf(accepted, problem: registry.problem);
  }

  /// The pages' snapshot of [accepted]; [problem] says why a newer state is not the one shown.
  RegistryPageSnapshot snapshotOf(RegistryRead accepted, {String? problem}) {
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
