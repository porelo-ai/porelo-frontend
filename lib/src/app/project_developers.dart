import 'package:flutter/foundation.dart';

import 'access_developers.dart';
import 'registry.dart';

import 'package:porelo_frontend/client.dart' show RegistryCard;

/// Core's person-list boundary; central-forge access is a prerequisite.
abstract interface class ProjectPeople {
  /// Reads accepted persons for this project.
  Future<AccessDevelopers> read(String project);

  /// Publishes and applies the selected person's access through verified signed state.
  Future<void> change(String project, AccessDeveloper person, {required bool remove});
}

/// Project-scoped registry selection and delivery recovery.
abstract interface class ProjectPersonActions implements ProjectPeople {
  /// The cards Core permits for this access scope.
  List<RegistryCard> get candidates;

  /// Changes the selected person's project lock without changing their host account.
  Future<void> lock(String login, {required bool locked});

  /// Retries the durable signed revision without another edit.
  Future<void> retry();

  /// Why a project change is currently unavailable.
  String? unavailable({bool delivery = false});

  /// Whether a delivery must finish before another edit.
  bool get pending;

  /// The verified host admission shown beside registration.
  String? get admission;
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
    access = await people.read(project);
    await people.change(project, person, remove: false);
    access = await people.read(project);
  });

  /// Removes only the person selected from the accepted project list.
  Future<void> remove(String login) => _doing(() async {
    access = await people.read(project);
    final person = access?.developers[login];
    if (person == null) throw const FormatException('The person is not in the accepted project list.');
    await people.change(project, person, remove: true);
    access = await people.read(project);
  });

  /// The scoped card picker and lock boundary, absent for an older implementation.
  ProjectPersonActions? get scoped => people is ProjectPersonActions ? people as ProjectPersonActions : null;

  /// Changes only the selected person's lock in this project.
  Future<void> lock(String login, {required bool locked}) => _doing(() async {
    final actions = scoped;
    if (actions == null) throw const RegistryRefusal('Project locking is unavailable.');
    await actions.lock(login, locked: locked);
    access = await people.read(project);
  });

  /// Resumes pending publication and delivery after the dialog or application reopened.
  Future<void> retry() => _doing(() async {
    final actions = scoped;
    if (actions == null) throw const RegistryRefusal('Project delivery recovery is unavailable.');
    await actions.retry();
    access = await people.read(project);
  });

  Future<void> _doing(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    problem = null;
    _notify();
    try {
      await action();
    } on RegistryRefusal catch (refused) {
      problem = refused.words;
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
