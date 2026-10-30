import 'package:flutter/foundation.dart';

import 'access_developers.dart';

/// Core's person-list boundary; central-forge access is a prerequisite.
abstract interface class ProjectPeople {
  /// Reads accepted persons for this project.
  Future<AccessDevelopers> read(String project);

  /// Publishes and applies the selected person's access through verified signed state.
  Future<void> change(String project, AccessDeveloper person, {required bool remove});
}

/// Edits persons without computer keys, address allocation or central collaborator changes.
class ProjectDevelopers extends ChangeNotifier {
  /// Uses the verified registry boundary supplied by Core.
  ProjectDevelopers({required this.project, required this.people});

  /// The selected project.
  final String project;

  /// The verified person and publication boundary.
  final ProjectPeople people;

  /// The last accepted list, retained on failure.
  AccessDevelopers? access;

  /// Whether a request is pending.
  bool busy = false;

  /// A public refusal with no dependency diagnostics.
  String? problem;
  bool _disposed = false;

  /// Refreshes the accepted list without replacing it on failure.
  Future<void> load() => _doing(() async {
    access = await people.read(project);
  });

  /// Adds a verified person selected from the registry.
  Future<void> addDeveloper(AccessDeveloper person) => _doing(() async {
    await people.change(project, person, remove: false);
    access = await people.read(project);
  });

  /// Removes only the person selected from the accepted project list.
  Future<void> remove(String login) => _doing(() async {
    final person = access?.developers[login];
    if (person == null) throw const FormatException('The person is not in the accepted project list.');
    await people.change(project, person, remove: true);
    access = await people.read(project);
  });
  Future<void> _doing(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    problem = null;
    _notify();
    try {
      await action();
    } on Exception {
      problem = 'The person change could not be confirmed. Refresh the verified project state.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
