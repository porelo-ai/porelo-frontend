import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Stopping following a project, which removes it from this machine.
///
/// **Not "deleting the project", and the difference is the whole reason this is safe to offer.**
/// The project is its repository, which is not on this machine and is never touched. What goes is
/// what this machine made of it — the clone it verified, the mirror, the image, the build
/// directory, the recorded upstream distance, and every task with its container, state and logs —
/// and following the repository again brings the project back.
///
/// It **refuses rather than decides**. Two things stop it, and they are not the same weight: a
/// running task is work cut off mid-flight, and an unreviewed push exists only in the mirror,
/// where nothing else has it anywhere. Saying them in one breath would flatten the one that
/// matters.
class ProjectDeletion extends ChangeNotifier {
  /// Which project is being removed, or null when nothing is.
  String? project;

  /// What the machine last answered — a preview, a refusal, or what it did.
  Deletion? answer;

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Why it could not be asked at all, in words. Null when nothing is wrong.
  String? problem;

  /// Whether anything about it is on screen.
  bool get open => project != null;

  /// Whether what is on screen is what *would* happen rather than what did.
  bool get previewing => answer?.outcome == DeleteOutcome.previewed;

  /// Whether it was refused and could be asked again meaning it.
  bool get refused => answer?.outcome.canBeForced ?? false;

  /// Whether it is done.
  bool get removed => answer?.outcome == DeleteOutcome.deleted;

  /// Asks what would go, removing nothing.
  ///
  /// Always first. This is the most destructive thing in the product and the list of what it
  /// takes is what somebody agrees to — not the sentence above the button.
  Future<void> consider(FleetBackend backend, String name) async {
    project = name;
    answer = null;
    await _asking(() => backend.unfollow(name, dryRun: true));
  }

  /// Removes it. With [force], despite unreviewed work or running tasks.
  Future<void> remove(FleetBackend backend, {bool force = false}) async {
    final name = project;
    if (name == null) return;
    await _asking(() => backend.unfollow(name, force: force ? true : null));
  }

  /// Puts what is on screen away.
  void letItBe() {
    project = null;
    answer = null;
    problem = null;
    notifyListeners();
  }

  /// What to say about the state it is in, in one line.
  String get words {
    final said = answer;
    final name = project;
    if (said == null || name == null) return '';
    return switch (said.outcome.name) {
      'PREVIEWED' => 'This stops following $name and removes it from this machine. '
          'Its repository is not touched.',
      'DELETED' => '$name is no longer followed here, and what Porelo built for it is gone. '
          'Its repository is not touched.',
      'HOLDS_WORK' => 'Work reached the gate for $name and nobody has reviewed it. '
          'Nothing was removed.',
      'TASKS_RUNNING' => 'Work is still running in $name. Nothing was removed.',
      'NO_SUCH_PROJECT' => 'Nothing on this machine knows a project called $name.',
      'FAILED' => 'Something could not be removed. ${said.detail}'.trim(),
      // A value a later release added. Say what came rather than guessing which side of it we are
      // on — the detail is the daemon's own sentence.
      _ => '${said.outcome.label}. ${said.detail}'.trim(),
    };
  }

  /// Why forcing is a different decision from the one already made, at the weight it deserves.
  ///
  /// **The two refusals are not equal.** A running task can be started again with the workspace it
  /// had; an unreviewed push is in the mirror and nowhere else, so forcing past it is the only
  /// action here that destroys something no other copy of exists.
  String get whatForcingCosts {
    final said = answer;
    if (said == null) return '';
    if (said.outcome == DeleteOutcome.holdsWork) {
      return 'Those commits are in the mirror and nowhere else — not in the operator’s '
          'checkout, not upstream. Removing this is the only way they can be lost.';
    }
    if (said.outcome == DeleteOutcome.tasksRunning) {
      return 'That work is cut off where it stands. The workspace goes with it, and the '
          'operator’s own repository does not.';
    }
    return '';
  }

  Future<void> _asking(Future<Deletion> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      answer = await ask();
    } on VarlinkException catch (refusal) {
      problem = refusal.simpleName == 'NoSuchProject'
          // A project left from before following: the machine lists it and follows nothing by that
          // name, so it cannot say what clearing it would take — and nothing goes without that.
          ? 'Nothing follows $project here, so the machine cannot say what clearing it away would '
              'take. Nothing was removed.'
          : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      // Deliberately does not say whether it happened. A removal that may or may not have run is
      // the one case where claiming either way sends somebody to the wrong place.
      problem = 'Lost contact with the machine: ${ex.message}. '
          'Whether anything was removed is not knowable from here — ask the machine.';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
