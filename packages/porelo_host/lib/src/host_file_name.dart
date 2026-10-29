/// A refusal safe to show without revealing file contents.
class HostFilesRefused implements Exception {
  /// Gives the reason without file contents.
  const HostFilesRefused(this.message);

  /// The safe explanation.
  final String message;
  @override
  String toString() => message;
}

/// Refuses [name] when it can select a parent directory, escape its folder, or read as an option.
void checkHostFileName(String name) {
  if (name.isEmpty ||
      name == '.' ||
      name.startsWith('-') ||
      name.contains('..') ||
      name.contains('/') ||
      name.contains(r'\') ||
      name.contains('\x00')) {
    throw const HostFilesRefused(
      'A name must not be empty, be a single dot, start with - or contain /, \\, .. or NUL.',
    );
  }
}
