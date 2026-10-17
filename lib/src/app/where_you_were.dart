import 'dart:async';

import 'machines.dart';
import 'settings.dart';
import 'shell_model.dart';

/// Remembers where somebody is, and puts them back there.
///
/// A restart — asked for, or because a newer version was installed — returns to the same
/// selection. Losing it is small every time and tiring every time, which is exactly the kind of
/// thing nobody bothers to report.
class WhereYouWere {
  /// Constructor taking where it is kept and what it is about.
  WhereYouWere(this._settings, this._machines, this._shell) {
    _machines.addListener(_remember);
    _shell.addListener(_remember);
  }

  final Settings _settings;
  final Machines _machines;
  final ShellModel _shell;

  /// Puts somebody back where they were.
  ///
  /// The selection is set without checking that it still exists, deliberately. Restoring races
  /// the machine still answering — projects arrive before tasks do — so a check here would keep
  /// whatever happened to have loaded and silently drop the rest. `FleetModel` already drops a
  /// selection that turns out not to exist, once it knows, which is the only moment it can be
  /// decided honestly.
  Future<void> restore() async {
    final place = await _settings.whereYouWere();

    final machine = place['machine'];
    if (machine != null) {
      for (final each in _machines.all) {
        if (each.name == machine) _machines.select(each);
      }
    }

    // Not the section: the window always opens on what needs a person.

    final fleet = _machines.fleet;
    final project = place['project'];
    if (project != null) fleet.selectProject(project);
    final task = place['task'];
    if (task != null) fleet.selectTask(task);
  }

  /// Stops remembering.
  void dispose() {
    _machines.removeListener(_remember);
    _shell.removeListener(_remember);
  }

  void _remember() {
    final fleet = _machines.fleet;
    unawaited(
      _settings.rememberWhereYouWere(<String, String>{
        'machine': _machines.current.name,
        if (fleet.selectedProject != null) 'project': fleet.selectedProject!.name,
        if (fleet.selectedTask != null) 'task': fleet.selectedTask!.name,
      }),
    );
  }
}
