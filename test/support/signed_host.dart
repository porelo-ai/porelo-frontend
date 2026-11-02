import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

/// A tunnel boundary that records destinations without running SSH.
class RecordingTunnels extends Tunnels {
  /// The exact machines requested by the action.
  final requested = <Machine>[];
  @override
  Future<bool> raiseFor(Machine machine) async {
    requested.add(machine);
    return true;
  }
}
