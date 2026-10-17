import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// What one task holds that never reached the gate.
///
/// **Asked for one task, when somebody opens it — never while drawing a list.** Every other field
/// about a task comes from one call for the whole list; this one runs git inside the container, so
/// on a list that redraws on every push it would be a call per row. That is the cost `since` and
/// `behindMeasured` both exist to avoid, and the reason this is a method of its own rather than a
/// field on `Task`.
class WorkHeld extends ChangeNotifier {
  /// Which task the answer belongs to, or null before anything was asked.
  String? task;

  /// What it said.
  HeldWork? answer;

  /// Whether it is being asked right now.
  bool busy = false;

  /// Why it could not be asked, in words.
  String? problem;

  int _asked = 0;

  /// Asks what one task holds.
  Future<void> look(FleetBackend backend, String name) async {
    final mine = ++_asked;
    task = name;
    answer = null;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      final said = await backend.workHeld(name);
      if (mine != _asked) return;
      answer = said;
    } on VarlinkException catch (refusal) {
      if (mine != _asked) return;
      // **A name that is no task is a refusal, not an unreadable answer.** Drawing it as
      // unreadable would make a wrong argument arrive as a legitimate reading — the shape that
      // cost an afternoon on `Backups`.
      problem = refusal.simpleName == 'NoSuchTask'
          ? 'This machine does not know a task called $name any more.'
          : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported {
      if (mine != _asked) return;
      // A daemon older than the method. Absent rather than wrong: the detail simply does not carry
      // the line, which is honest — nothing here knows.
      answer = null;
    } finally {
      if (mine == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Forgets it, for a task that is no longer open.
  void letItBe() {
    task = null;
    answer = null;
    problem = null;
    notifyListeners();
  }

  /// What to say about [name], or empty when there is nothing to say about it.
  ///
  /// **Three sentences, not two.** *Holds nothing* and *nobody could look* are different answers
  /// and only one of them makes it safe to remove a task without asking — and *holds* and *held*
  /// are different again, because a stopped task's answer is what was true when it stopped.
  String words(String name, {DateTime? now}) {
    if (task != name) return '';
    if (problem != null) return problem!;
    if (busy) return 'asking the machine…';
    final said = answer;
    if (said == null) return '';

    if (!said.readable) {
      return 'nothing recorded what it held — it was killed, rebooted, or stopped by an older '
          'Porelo';
    }
    final what = said.holdsSomething ? _counts(said) : 'nothing';
    if (said.current) {
      return said.holdsSomething ? 'holds $what' : 'holds nothing that never reached the gate';
    }
    final ago = howLongAgo(said.asOf, now: now);
    return said.holdsSomething
        ? 'held $what when it stopped$ago'
        : 'held nothing when it stopped$ago';
  }

  static String _counts(HeldWork said) {
    final parts = <String>[
      if (said.unpushedCommits > 0)
        '${said.unpushedCommits} '
            '${said.unpushedCommits == 1 ? 'unpushed commit' : 'unpushed commits'}',
      if (said.changedFiles > 0)
        '${said.changedFiles} '
            '${said.changedFiles == 1 ? 'changed file' : 'changed files'}',
    ];
    return parts.join(' and ');
  }

  /// How long ago the answer was true, as a clause, or empty when nothing can say.
  static String howLongAgo(DateTime? at, {DateTime? now}) {
    if (at == null) return '';
    final elapsed = (now ?? DateTime.now()).difference(at);
    if (elapsed.isNegative) return '';
    if (elapsed.inMinutes < 1) return ', less than a minute ago';
    if (elapsed.inMinutes == 1) return ', 1 minute ago';
    if (elapsed.inHours < 1) return ', ${elapsed.inMinutes} minutes ago';
    if (elapsed.inHours == 1) return ', 1 hour ago';
    if (elapsed.inDays < 1) return ', ${elapsed.inHours} hours ago';
    if (elapsed.inDays == 1) return ', 1 day ago';
    return ', ${elapsed.inDays} days ago';
  }
}
