import 'signed_host_actions.dart';

/// Verified admission shared by the register and join actions.
class AccessJoin {
  /// Requires a complete Core verdict before a host operation can start.
  AccessJoin(this.state) {
    state.check(state.project);
  }

  /// The accepted project, host and admin signers.
  final VerifiedHostProject state;
}
