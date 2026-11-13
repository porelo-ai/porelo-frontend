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
    _savedNavigation = Map.of(_settings.shellNavigation);
    _restored = false;
    _shell.initializeNavigation(_machines.current);
    _machines.addListener(_remember);
    _shell.addListener(_remember);
  }

  final Settings _settings;
  final Machines _machines;
  final ShellModel _shell;
  late final Map<String, Object?> _savedNavigation;
  late bool _restored;

  /// Puts somebody back where they were.
  ///
  /// The selection is set without checking that it still exists, deliberately. Restoring races
  /// the machine still answering — projects arrive before tasks do — so a check here would keep
  /// whatever happened to have loaded and silently drop the rest. `FleetModel` already drops a
  /// selection that turns out not to exist, once it knows, which is the only moment it can be
  /// decided honestly.
  Future<void> restore() async {
    final place = await _settings.whereYouWere();
    // A place the person chose while the window started stands, and the saved selection with it goes.
    if (_shell.movedBeforeRestore) {
      _shell.restoreNavigation(_savedNavigation, _machines.all, _machines.current);
      _restored = true;
      _remember();
      return;
    }

    final machine = place['machine'];
    if (machine != null) {
      for (final each in _machines.all) {
        if (each.name == machine) _machines.select(each);
      }
    }

    _shell.restoreNavigation(_savedNavigation, _machines.all, _machines.current);

    final destination = _shell.place.machine;
    if (destination != null) _machines.select(destination);

    final project = place['project'];
    final task = place['task'];
    // A machine not watched yet, as while it is opened, takes the selection once it is: the fleet watching it then.
    final current = _machines.current;
    _stopWaiting();
    var done = false;
    _waiting = _machines.follow(current, (fleet) {
      if (done || fleet == null) return;
      done = true;
      // Called from within the first call too, where what stops it is not kept yet.
      scheduleMicrotask(_stopWaiting);
      if (project != null) fleet.selectProject(project);
      if (task != null) fleet.selectTask(task);
    });
    _restored = true;
    _remember();
  }

  void Function()? _waiting;

  void _stopWaiting() {
    _waiting?.call();
    _waiting = null;
  }

  /// Stops remembering.
  void dispose() {
    _stopWaiting();
    _machines.removeListener(_remember);
    _shell.removeListener(_remember);
  }

  void _remember() {
    if (!_restored) return;
    unawaited(_settings.rememberShellNavigation(_shell.navigation));
    // One not opened yet has no selection to keep, and keeping none would forget the one saved.
    final fleet = _machines.watching(_machines.current);
    if (fleet == null) return;
    unawaited(
      _settings.rememberWhereYouWere(<String, String>{
        'machine': _machines.current.name,
        if (fleet.selectedProject != null) 'project': fleet.selectedProject!.name,
        if (fleet.selectedTask != null) 'task': fleet.selectedTask!.name,
      }),
    );
  }
}
