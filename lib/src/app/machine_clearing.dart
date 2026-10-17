import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'forge.dart';
import 'forge_connection.dart';
import 'machine_binding.dart';
import 'project_workspace.dart';

/// Clearing a machine, or one project on it, of everything Porelo put there and at the forge, in one
/// step: the machine's `Clear` does what only it can; then each deploy key it names is removed at
/// the forge with the person's sign-in, and its line taken out of each project's `machine-signers`
/// in one signed commit. What was removed and what was left is said, thing by thing (walk 8:
/// when the work is done, everything on the server can be cleared very simply).
class MachineClearing extends ChangeNotifier {
  /// Constructor taking the machine, how the forge is reached, and what is cleared: [project], or
  /// everything where it is null.
  MachineClearing(this._machine, this.forges, {required this.machineName, this.project});

  final FleetBackend _machine;

  /// The forge sign-in kept here, which removes keys and commits the signers' change.
  final ForgeConnection forges;

  /// The machine, as the person calls it.
  final String machineName;

  /// The project cleared, or null for the whole machine.
  final String? project;

  /// What the dry run said would go: shown before anything is done.
  Cleared? preview;

  /// What clearing answered.
  Cleared? cleared;

  /// What was done at the forge and in `machine-signers`, one sentence each.
  final List<String> done = <String>[];

  /// Why it could not be asked or done, in words.
  String? problem;

  /// Whether something is under way.
  bool busy = false;

  /// Asks the machine what clearing would remove, changing nothing.
  Future<void> look() => _doing(() async {
    preview = await _machine.clear(project: project, dryRun: true);
  });

  /// Clears it: the machine's part, then the forge's. [force] clears unreviewed work and running
  /// tasks too, which a first call refuses.
  Future<void> clearIt({bool force = false}) => _doing(() async {
    final answer = await _machine.clear(project: project, force: force);
    cleared = answer;
    if (answer.refused) return;
    final forge = forges.forge;
    if (forge == null) {
      for (final key in answer.keys) {
        done.add('Left ${key.title}: no forge is signed in here to remove it with.');
      }
      return;
    }
    await removeAtTheForge(forge, answer.keys, done.add);
    await _takeOutTheSigner(forge, answer);
  });

  /// Takes the machine's line out of `machine-signers` in each project's own repository: the one
  /// its read-only key is for.
  Future<void> _takeOutTheSigner(Forge forge, Cleared answer) async {
    if (answer.signer.trim().isEmpty) return;
    final own = <String>{
      for (final key in answer.keys)
        if (!key.writeAccess) ?onGitHub(key.upstream),
    };
    for (final fullName in own) {
      try {
        final repository = await forge.repository(fullName);
        final workspace = forges.workspace(repository);
        if (workspace == null) {
          done.add('Left $machineName’s line in $fullName’s machine-signers: no token here reaches it.');
          continue;
        }
        await workspace.open();
        final text = await workspace.readFile('machine-signers');
        final kept = text == null ? null : withoutSigner(text, answer.signer, machineName);
        if (kept == null) {
          done.add('$fullName’s machine-signers does not hold $machineName’s line; nothing to change.');
          continue;
        }
        final held = await workspace.signingKeys();
        final login = forges.account?.login ?? '';
        final person = orderSigningKeys(held, await signingKeysAt(forge, login)).chosen;
        if (person == null) {
          done.add('Left $machineName’s line in $fullName’s machine-signers: choose your signing key first.');
          continue;
        }
        await workspace.writeFile('machine-signers', kept);
        await workspace.commitAndPush(
          'Take $machineName out',
          person,
          login: login,
          files: const <String>['machine-signers'],
        );
        done.add('Took $machineName’s line out of $fullName’s machine-signers, committed signed and pushed.');
      } on ForgeRefused catch (refused) {
        done.add('Left $machineName’s line in $fullName’s machine-signers: ${refused.words}');
      } on WorkspaceRefused catch (refused) {
        done.add('Left $machineName’s line in $fullName’s machine-signers: ${refused.words}');
      }
    }
  }

  Future<void> _doing(Future<void> Function() action) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await action();
    } on FeatureNotSupported {
      problem = '$machineName cannot be cleared in one step: its Porelo is older than that.';
    } on VarlinkException catch (refusal) {
      problem = '$machineName refused it: ${refusal.parameters['message'] ?? refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with $machineName: ${ex.message}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
