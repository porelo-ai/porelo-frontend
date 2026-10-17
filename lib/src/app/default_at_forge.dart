import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'forge.dart';

/// Working on a forge's repository without a project, from its card on the forge's page (walk 10:
/// Default left Projects, and its one task went to where the repository is seen).
///
/// The repository goes into the machine's `default` and the machine gets a key of its own there, as
/// working on a project gives it; taken out, its key goes at the forge too. Answers what was done.
class DefaultAtForge {
  /// Constructor taking the machine and the forge.
  const DefaultAtForge(this._machine, this._forge, {required this.machineName});

  final FleetBackend _machine;
  final Forge _forge;

  /// What the person calls the machine.
  final String machineName;

  /// Puts [repository] into `default`, unless it is there, and gives the machine its key at the forge.
  Future<String> add(ForgeRepository repository) async {
    final there = await _inDefault(repository);
    final added = there ?? await _machine.addToDefault(repository.sshUrl);
    final key = await _machine.deployKey(defaultProject, repository: added.name);
    final held = await _forge.deployKeys(repository.fullName);
    if (!held.any((each) => keyPart(each.key) == keyPart(key.publicKey))) {
      await _forge.addDeployKey(repository.fullName, title: key.title, key: key.publicKey, readOnly: false);
    }
    return there != null
        ? '${repository.fullName} is worked on without a project on $machineName already; its key is there.'
        : '${repository.fullName} is worked on without a project on $machineName now, with a key of its own at '
              '${_forge.name}. Start work on it under Work.';
  }

  /// Takes [repository] out of `default`, and the keys the machine forgot off the forge.
  Future<String> remove(ForgeRepository repository) async {
    final there = await _inDefault(repository);
    if (there == null) return '${repository.fullName} was not worked on without a project on $machineName.';
    final done = await _machine.removeFromDefault(there.name);
    var removed = 0;
    for (final held in await _forge.deployKeys(repository.fullName)) {
      if (done.keys.any((each) => keyPart(each.publicKey) == keyPart(held.key))) {
        await _forge.removeDeployKey(repository.fullName, held.id);
        removed++;
      }
    }
    return '${repository.fullName} is no longer worked on without a project on $machineName. Its mirror stays '
        'there${removed == 0 ? '' : '; its key is removed at ${_forge.name}'}.';
  }

  Future<DefaultRepository?> _inDefault(ForgeRepository repository) async =>
      (await _machine.defaultRepositories()).where((each) => each.upstream == repository.sshUrl).firstOrNull;

  /// The type and key of a public key, without its comment.
  static String keyPart(String key) => key.trim().split(RegExp(r'\s+')).take(2).join(' ');
}
