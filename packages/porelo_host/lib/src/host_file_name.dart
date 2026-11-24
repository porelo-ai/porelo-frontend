/// A refusal safe to show without revealing file contents.
class HostFilesRefused implements Exception {
  /// Gives the reason without file contents.
  const HostFilesRefused(this.message, {this.inTheWay = false});

  /// The safe explanation.
  final String message;

  /// Whether files already standing where these go, which this writer did not leave as they are, stopped it: a cause on
  /// this computer, apart from a path or a card refused.
  final bool inTheWay;
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
