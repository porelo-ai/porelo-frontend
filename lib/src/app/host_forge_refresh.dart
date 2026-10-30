import 'package:porelo_frontend/client.dart';

/// Refreshes only the joined host's forge, without contacting the central forge.
///
/// Core must supply this boundary after its served contract identifies the local
/// target. The legacy upstream operation is not a substitute.
abstract interface class HostForgeRefresh {
  /// Refreshes the followed project from the host's forge alone.
  Future<List<Followed>> refresh(String project);

  /// Measures the mirror against the host's forge alone.
  Future<Synced> sync(String project, {String? repository});
}
