/// A startup role that determines which commands the interface offers.
enum Role {
  /// Ordinary work, held on every start.
  user('user'),

  /// Server preparation, recovery, teardown, and VPN setup.
  hostAdmin('host-admin'),

  /// Placing projects on prepared servers.
  projectAdmin('project-admin'),

  /// Reserved for access administration, with no commands of its own.
  accessAdmin('access-admin');

  const Role(this.argument);

  /// The spelling accepted in the startup argument.
  final String argument;
}

/// The roles held for this process, independent of saved settings.
class Roles {
  /// Ordinary work without administration.
  const Roles() : _held = const {Role.user};

  Roles._(Set<Role> held) : _held = Set.unmodifiable(held);

  /// Reads comma-separated startup roles, refusing unknown or missing values.
  factory Roles.fromArguments(List<String> arguments) {
    final held = <Role>{Role.user};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String value;
      if (argument == '--roles') {
        if (++index == arguments.length || arguments[index].startsWith('--')) {
          throw FormatException('Expected a comma-separated list after --roles. $_known');
        }
        value = arguments[index];
      } else if (argument.startsWith('--roles=')) {
        value = argument.substring('--roles='.length);
      } else {
        continue;
      }
      for (final name in value.split(',').map((name) => name.trim())) {
        final role = Role.values.where((role) => role.argument == name).firstOrNull;
        if (role == null) throw FormatException('Unknown role "$name". $_known');
        held.add(role);
      }
    }
    return Roles._(held);
  }

  final Set<Role> _held;

  static String get _known => 'Known roles: ${Role.values.map((role) => role.argument).join(', ')}.';

  /// Whether commands belonging to [role] are offered on this start.
  bool holds(Role role) => _held.contains(role);
}

/// The process's startup roles, replaceable in tests like the desktop environment.
Roles roles = const Roles();
