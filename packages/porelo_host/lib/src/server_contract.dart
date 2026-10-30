import 'host_record.dart';
import 'remote.dart';

/// Checks an account or project name before it reaches a host operation.
void checkAdminName(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(value)) {
    throw const FormatException('Use a lower-case login or project name, at most 32 characters.');
  }
}

/// The agreed server-setup boundary, implemented when the host serves its final contract.
abstract interface class ServerPreparation {
  /// Prepares this existing SSH host with the verified host admin's public signers.
  Future<PreparedHost> prepare({
    required Remote remote,
    required String name,
    required String address,
    required List<String> adminSigners,
  });
}
