import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/signed_host_actions.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_admin.dart';

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

/// A Core and host stand-in driven by each test's verified state and result.
class SignedHostFake implements SignedHostActions {
  /// Supplies only accepted public state unless a test changes it.
  SignedHostFake()
    : state = VerifiedHostProject(
        project: 'demo',
        host: PreparedHost.read(hostValues()),
        revision: 'a' * 40,
        adminSigners: [personKey],
        admitted: true,
      );

  /// The next verification result.
  VerifiedHostProject state;

  /// A failure to send on register or join.
  Exception? refused;

  /// A different host result, when a test needs a mismatched revision.
  String? observed;

  /// Calls as they reach the boundary.
  final calls = <String>[];
  @override
  Future<VerifiedHostProject> verify(String project, {required bool registering}) async {
    calls.add('verify $project ${registering ? 'register' : 'join'}');
    return state;
  }

  @override
  Future<Machine> connect(VerifiedHostProject state) async {
    calls.add('ssh ${state.host.name}');
    return Machine(
      name: 'worker on ${state.host.name}',
      kind: 'host',
      hostProject: state.host.name,
      host: 'worker@${state.host.address}',
      socketPath: '/unused',
      remoteSocket: '/run/user/1007/porelo',
    );
  }

  @override
  Future<String> register(VerifiedHostProject state, Machine machine) async {
    calls.add('register ${state.project}');
    if (refused != null) throw refused!;
    return observed ?? state.revision;
  }
}
