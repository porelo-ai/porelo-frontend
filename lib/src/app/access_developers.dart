import 'package:porelo_host/porelo_host.dart';

/// One verified person's project access, independent of their computers.
class AccessDeveloper {
  /// Retains Core's public person verdict without writing a second access-file format.
  AccessDeveloper({required this.login, required this.role, required this.fingerprint, this.locked = false}) {
    checkAdminName(login);
    if (!const {'admin', 'developer'}.contains(role) || !RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$').hasMatch(fingerprint)) {
      throw const FormatException('A verified project role and key fingerprint are required.');
    }
  }

  /// The person's stable login.
  final String login;

  /// The verified role in this project.
  final String role;

  /// The current admitted key's fingerprint.
  final String fingerprint;

  /// Whether this project locks the person.
  final bool locked;
}

/// Core's accepted person list; signature verification and file writing remain in Core.
class AccessDevelopers {
  /// Keeps one verified entry per login.
  AccessDevelopers(Iterable<AccessDeveloper> people)
    : developers = Map.unmodifiable({for (final person in people) person.login: person});

  /// The accepted persons keyed by login.
  final Map<String, AccessDeveloper> developers;
}

/// Checks a central forge login before it reaches an API path.
void checkForgeLogin(String login) {
  if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$').hasMatch(login) || login.contains('--')) {
    throw const FormatException('The forge login is invalid.');
  }
}
