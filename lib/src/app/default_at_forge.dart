import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'forge.dart';

/// Working on a forge's repository without a project, from its card on the forge's page (walk 10:
/// Default left Projects, and its one task went to where the repository is seen).
///
/// The repository goes into the machine's `default` over https, using its vault token.
/// Removing it leaves access at the forge alone.
class DefaultAtForge {
  /// Constructor taking the machine and the forge.
  const DefaultAtForge(this._machine, {required this.machineName});

  final FleetBackend _machine;

  /// What the person calls the machine.
  final String machineName;

  /// Puts [repository] into `default`, unless it is there.
  Future<String> add(ForgeRepository repository) async {
    final there = await _inDefault(repository);
    if (there == null) await _machine.addToDefault(repository.httpsUrl);
    return there != null
        ? '${repository.fullName} is worked on without a project on $machineName already.'
        : '${repository.fullName} is worked on without a project on $machineName now. Start work on it under Work.';
  }

  /// Takes a repository out of default without changing access at the forge.
  Future<String> remove(ForgeRepository repository) async {
    final there = await _inDefault(repository);
    if (there == null) return '${repository.fullName} was not worked on without a project on $machineName.';
    final done = await _machine.removeFromDefault(there.name);
    return <String>[
      done.removed
          ? '${repository.fullName} is no longer worked on without a project on $machineName. Its mirror stays there.'
          : '${repository.fullName} was not in default any more.',
      for (final key in done.keys) key.title,
    ].join(' ');
  }

  Future<DefaultRepository?> _inDefault(ForgeRepository repository) async => (await _machine.defaultRepositories())
      .where((each) => each.upstream == repository.httpsUrl || each.upstream == repository.sshUrl)
      .firstOrNull;
}
