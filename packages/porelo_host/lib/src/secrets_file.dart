import 'host_file_name.dart' show HostFilesRefused;

/// Validation shared by encrypted-storage references and legacy rental recovery.
abstract final class SecretsFile {
  /// Refuses unsafe legacy rental identifiers.
  static void checkHost(String host) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(host) || host == '.' || host == '..') {
      throw const HostFilesRefused('A project name holds only letters, digits, ".", "_" and "-".');
    }
  }

  /// Refuses a path that cannot be passed as one plain shell word.
  static void checkPath(String value) {
    if (!value.startsWith('/') || value.length < 2 || RegExp(r'[^A-Za-z0-9 /._:@%+=,-]').hasMatch(value)) {
      throw const FormatException('A plain absolute encrypted-storage path is required.');
    }
  }

  /// Refuses unsafe vault entry names.
  static void checkKeyName(String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name)) {
      throw const HostFilesRefused('A vault entry name holds only letters, digits, ".", "_" and "-".');
    }
  }
}
