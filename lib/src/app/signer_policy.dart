import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Core's signer policy for a project: the one place the interface learns who signs and who is accepted.
///
/// The interface never builds a signer list of its own, nor takes one from a forge: what it signs with and what it
/// accepts are what this answers. An implementation may throw anything when Core answers nothing usable; the caller
/// refuses then.
abstract interface class SignerPolicy {
  /// The person's own public key and the allowed-signers lines in force for [project].
  Future<ProjectSigners> signers(String project);

  /// Core's recorded verdict on [revision], a commit of [project] that already arrived.
  Future<CommitVerdict> verdict(String project, String revision);
}

/// Asks Core through this computer's own daemon, the one that holds the person's registry state.
class DaemonSignerPolicy implements SignerPolicy {
  /// Constructor taking this computer's daemon.
  DaemonSignerPolicy(this.backend);

  /// This computer's daemon, never a forwarded one: the policy is the person's own Core's.
  final PoreloBackend backend;

  @override
  Future<ProjectSigners> signers(String project) async {
    await backend.open();
    return backend.projectSigners(project);
  }

  @override
  Future<CommitVerdict> verdict(String project, String revision) async {
    await backend.open();
    return backend.commitVerdict(project, revision);
  }
}
