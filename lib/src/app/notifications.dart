import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'authorizations.dart';
import 'clearance.dart';
import 'desk.dart';
import 'fleet_model.dart';
import 'machines.dart';
import 'operations.dart';
import 'settings.dart';

/// How much a notification is entitled to interrupt.
enum Urgency {
  /// A decision is waiting and the watcher will give up on its own. This is the one with a
  /// deadline, and the only thing here that may insist.
  waiting,

  /// Something finished and did what it said.
  finishedWell,

  /// Something finished and did not.
  finishedBadly,
}

/// One thing worth telling somebody who is not looking at the window.
///
/// Not `Notification`: Flutter has one of those, and two classes with one name in a file that
/// imports both is a needless argument with the analyzer.
@immutable
class Announcement {
  /// Constructor taking what to say and what it is about.
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.urgency,
    this.project = '',
  });

  /// Identifies what it is about, so the same thing is not raised twice and acting on it can
  /// find its way back.
  final String id;

  /// One line.
  final String title;

  /// The detail under it.
  final String body;

  /// How much it may interrupt.
  final Urgency urgency;

  /// Which project it belongs to, so it can be turned off per project.
  final String project;
}

/// Raises a notification on the desktop.
///
/// A seam, so what is *decided* can be tested without a notification daemon: the rules about when
/// to raise, what to say and what to stay quiet about are the requirement, and the transport is
/// not.
abstract class Notifier {
  /// Raises one. [onOpened] runs if somebody acts on it.
  Future<void> raise(Announcement note, {required VoidCallback onOpened});

  /// Why nothing can be raised, or null when it can.
  String? get problem;
}

/// The desktop's own notifications, through `notify-send`.
///
/// Running `notify-send` is not a breach of the rule against shelling out: that rule is about
/// never building a second implementation of the *domain* by parsing the `porelo` CLI. This is the
/// desktop, and nothing about the contract goes near it.
///
/// **On Windows nothing is raised yet**, and that is said once rather than silently, as a missing
/// `notify-send` is: Windows' own notifications need the app registered with the shell, which comes
/// with the MSIX.
class DesktopNotifier implements Notifier {
  /// Constructor, optionally told it runs on Windows.
  DesktopNotifier({bool? onWindows}) : _onWindows = onWindows ?? desk.isWindows;

  final bool _onWindows;

  @override
  String? problem;

  @override
  Future<void> raise(Announcement note, {required VoidCallback onOpened}) async {
    if (_onWindows) {
      problem = 'Nothing could be notified: this build raises no notifications on Windows yet.';
      return;
    }
    try {
      final process = await Process.start('notify-send', <String>[
        '--app-name=Porelo',
        '--urgency=${switch (note.urgency) {
          Urgency.waiting => 'critical',
          Urgency.finishedBadly => 'normal',
          Urgency.finishedWell => 'low',
        }}',
        // -A implies --wait, so the process lives until the notification is dismissed and prints
        // the action's name if one was chosen. That is the whole of "acting on it opens the work".
        '--action=open=Open',
        note.title,
        note.body,
      ]);
      unawaited(process.stdout
          .transform(utf8.decoder)
          .join()
          .then((chosen) => chosen.trim() == 'open' ? onOpened() : null));
      problem = null;
    } on ProcessException {
      // Said once rather than silently: believing notifications are on when they are not is worse
      // than knowing they are off, which is the whole point of this requirement.
      problem = 'Nothing could be notified: this desktop has no notify-send.';
    }
  }
}

/// What gets told to somebody who is not looking at the window.
///
/// Unattended means unattended: a decision waiting inside a window nobody has open is the same as
/// no decision at all. **The interface has to be running** — a closed window is covered, a closed
/// application is not, and nothing about a forwarded socket changes that.
class Notifications extends ChangeNotifier {
  /// Constructor taking how to raise one and where the choices are kept.
  Notifications(this._notifier, this._settings);

  final Notifier _notifier;
  final Settings _settings;
  final Set<String> _announced = <String>{};
  Set<String> _muted = <String>{};
  bool _disposed = false;

  /// Why nothing can be raised, or null when it can.
  String? get problem => _notifier.problem;

  /// Projects nobody wants to hear about.
  Set<String> get muted => Set<String>.unmodifiable(_muted);

  /// Whether this project is turned off.
  bool mutedFor(String project) => _muted.contains(project);

  /// Reads back which projects were turned off.
  Future<void> load() async {
    _muted = await _settings.mutedProjects();
    _notify();
  }

  /// Turns a project on or off.
  Future<void> setMuted(String project, {required bool muted}) async {
    if (muted) {
      _muted.add(project);
    } else {
      _muted.remove(project);
    }
    await _settings.rememberMutedProjects(_muted);
    _notify();
  }

  /// Tells somebody about decisions waiting on one machine.
  ///
  /// [projectOf] resolves a task to its project, because a question knows which task it is about
  /// and the switch is per project.
  void watchClearance(
    Clearance clearance, {
    required String Function(String task) projectOf,
    required void Function(Prompt prompt) open,
  }) {
    clearance.addListener(() {
      for (final prompt in clearance.waiting) {
        _raise(
          Announcement(
            id: 'clearance/${prompt.identity}',
            title: 'Something is waiting for you',
            body: '${prompt.task} is asking to reach ${prompt.shown}',
            urgency: Urgency.waiting,
            project: projectOf(prompt.task),
          ),
          () => open(prompt),
        );
      }
    });
  }

  /// Tells somebody about decisions waiting on every machine — those there now and any added later.
  ///
  /// **Followed, not listed once.** Watching only the machines there at start left one added through
  /// *Watch another machine…* asking questions nobody was told about.
  void watchMachines(Machines machines, {required void Function(Prompt prompt) open}) {
    final watched = Expando<bool>();
    void everyMachine() {
      for (final machine in machines.all) {
        final fleet = machines.of(machine);
        if (watched[fleet] ?? false) continue;
        watched[fleet] = true;
        watchClearance(fleet.clearance, projectOf: (task) => _projectOf(fleet, task), open: open);
        watchAuthorizations(fleet.authorizations, machine: machine.name);
      }
    }

    everyMachine();
    machines.addListener(everyMachine);
    _stopWatching.add(() => machines.removeListener(everyMachine));
  }

  /// Tells somebody about an authorization work waits for, as a question: work that cannot use a
  /// service until somebody grants it is blocked the way a connection nobody allowed is.
  ///
  /// Once per raising: a grant that ends again later is a new question, and said again.
  void watchAuthorizations(Authorizations authorizations, {required String machine, VoidCallback? open}) {
    authorizations.addListener(() {
      for (final needed in authorizations.open) {
        final forWhat = needed.task.isEmpty ? '' : ' for ${needed.task}';
        _raise(
          Announcement(
            id: 'authorization/$machine/${needed.credential}/${needed.state}/${needed.at}',
            title: 'Something is waiting for you',
            body: needed.state == 'ended'
                ? '${needed.credential} needs granting again$forWhat, on $machine'
                : '${needed.credential} needs a grant$forWhat, on $machine',
            urgency: Urgency.waiting,
            project: needed.project,
          ),
          open ?? () {},
        );
      }
    });
  }

  final List<void Function()> _stopWatching = <void Function()>[];

  static String _projectOf(FleetModel fleet, String task) => fleet.tasks
      .firstWhere((each) => each.name == task, orElse: () => Task.from(const <String, dynamic>{}))
      .project;

  /// Tells somebody when something this session started has finished.
  ///
  /// Success and failure are told apart because the session knows what it ran. A *task* that ends
  /// cannot be told apart the same way: `activity` says `DEAD` for stopped, finished and killed
  /// alike, and `state` is prose that must not be parsed.
  void watchOperations(
    Operations operations, {
    required void Function(Operation operation) open,
  }) {
    operations.addListener(() {
      for (final operation in operations.all) {
        // Read back from an earlier run: whatever it had to say was said then, or waits in Needs you.
        if (operation.running || operation.fromBefore) continue;
        _raise(
          Announcement(
            id: 'operation/${operation.id}',
            title: operation.failed ? 'That did not work' : 'That is done',
            body: '${operation.title}. ${operation.summary}',
            urgency:
                operation.failed ? Urgency.finishedBadly : Urgency.finishedWell,
          ),
          () => open(operation),
        );
      }
    });
  }

  void _raise(Announcement note, VoidCallback onOpened) {
    if (_announced.contains(note.id)) return;
    if (note.project.isNotEmpty && mutedFor(note.project)) return;
    _announced.add(note.id);
    unawaited(_notifier.raise(note, onOpened: onOpened).then((_) => _notify()));
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final stop in _stopWatching) {
      stop();
    }
    super.dispose();
  }
}
