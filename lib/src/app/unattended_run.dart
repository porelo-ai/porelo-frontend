import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_model.dart';
import 'machines.dart';
import 'operations.dart';

/// The task an unattended start watches, bound to its original machine and project.
class UnattendedRun extends ChangeNotifier {
  /// Constructor retaining the start's target, independent of the frame's selection.
  UnattendedRun({
    required this.machine,
    required this.fleet,
    required this.project,
    required this.named,
    required this.operation,
    required this.operations,
  });

  /// Where this work was started.
  final Machine machine;

  /// The task list arriving from that machine's Watch.
  final FleetModel fleet;

  /// The project name given to Start.
  final String project;

  /// The task name given to Start, never derived from a container name.
  final String named;

  /// The start's own progress, which leaving this view never cancels.
  final Operation operation;

  /// Announces the final start reply.
  final Operations operations;

  /// The most recent task report, or null until this machine lists it.
  Task? get task => fleet.tasks.where((task) => task.project == project && task.task == named).firstOrNull;

  /// The project's current configuration on the run's own machine.
  Project? get configuration => fleet.projects.where((each) => each.name == project).firstOrNull?.project;

  /// The last output line reported by Tail, without retaining the whole log.
  String? lastLine;

  /// Why the task report or last line cannot be read.
  String? problem;

  StreamSubscription<List<String>>? _tail;
  Timer? _refreshing;
  bool _readingReport = false;
  String? _container;
  bool _following = false;
  bool _refreshed = false;

  /// Observes the run while its view is open.
  void follow() {
    if (_following) return;
    _following = true;
    fleet.addListener(_changed);
    operations.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (operation.running || operation.failed) return;
    if (!_refreshed) {
      _refreshed = true;
      unawaited(_refreshReport());
    }
    final listed = task;
    if (listed != null && _container != listed.name) {
      unawaited(_tail?.cancel());
      _container = listed.name;
      lastLine = null;
      problem = null;
      try {
        _tail = fleet.backend
            .tailLog(listed.name, 'task.log', last: 1, formatted: true)
            .listen(
              (lines) {
                if (!_following || lines.isEmpty) return;
                lastLine = lines.last;
                // lastWrote alone does not trigger Watch; read its timestamp after output, coalescing bursts.
                _refreshing ??= Timer(const Duration(seconds: 3), () {
                  _refreshing = null;
                  unawaited(_refreshReport());
                });
                notifyListeners();
              },
              onError: (Object error) {
                if (!_following) return;
                problem = '$error';
                notifyListeners();
              },
              cancelOnError: true,
            );
      } on Object catch (error) {
        problem = '$error';
      }
    }
    notifyListeners();
  }

  Future<void> _refreshReport() async {
    if (!_following || _readingReport) return;
    _readingReport = true;
    try {
      await fleet.refresh(quietly: true);
    } on Object catch (error) {
      if (_following) {
        problem = '$error';
        notifyListeners();
      }
    } finally {
      _readingReport = false;
    }
  }

  /// Stops observing this view; the start and task continue independently.
  void unfollow() {
    if (!_following) return;
    _following = false;
    fleet.removeListener(_changed);
    operations.removeListener(_changed);
    _refreshing?.cancel();
    _refreshing = null;
    unawaited(_tail?.cancel());
    _tail = null;
    _container = null;
  }

  @override
  void dispose() {
    unfollow();
    super.dispose();
  }
}
