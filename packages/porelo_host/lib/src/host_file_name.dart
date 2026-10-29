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

final _projectName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)*$');

/// Refuses [name] as a project's own-account setup folder unless it is ASCII letters, digits, `_`, `-` and inner
/// single dots, starting with a letter or digit, at most 64 characters: nothing a shell, scp, YAML or Windows reads
/// otherwise, and never a staging name, which starts with `-`.
void checkOwnAccountProjectName(String name) {
  if (name.length > 64 || !_projectName.hasMatch(name)) {
    throw const HostFilesRefused(
      'A project name is ASCII letters, digits, _ and -, with single dots inside, starting with a letter or digit.',
    );
  }
}
