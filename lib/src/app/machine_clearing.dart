import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'forge_connection.dart';
import 'quiet_after_dispose.dart';

/// Clears a machine or one project through the daemon’s preview and confirmed operation.
class MachineClearing extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking the machine, how the forge is reached, and what is cleared: [project], or
  /// everything where it is null.
  MachineClearing(this._machine, this.forges, {required this.machineName, this.project});

  final FleetBackend _machine;

  /// Forge context retained for callers; clearing writes no signing policy.
  final ForgeConnection forges;

  /// The machine, as the person calls it.
  final String machineName;

  /// The project cleared, or null for the whole machine.
  final String? project;

  /// What the dry run said would go: shown before anything is done.
  Cleared? preview;

  /// What clearing answered.
  Cleared? cleared;

  /// Additional completion details, when supplied.
  final List<String> done = <String>[];

  /// Why it could not be asked or done, in words.
  String? problem;

  /// Whether something is under way.
  bool busy = false;

  /// Reads followed repositories and the daemon’s dry run before clearing.
  Future<void> look() => _doing(() async {
    preview = await _machine.clear(project: project, dryRun: true);
  });

  /// Clears the daemon’s selected state. [force] clears unreviewed work and running
  /// tasks too, which a first call refuses.
  Future<void> clearIt({bool force = false}) => _doing(() async {
    final answer = await _machine.clear(project: project, force: force);
    cleared = answer;
    if (answer.refused) return;
  });

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
