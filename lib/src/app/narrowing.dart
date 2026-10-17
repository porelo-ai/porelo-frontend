import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Taking a name back from a task that is **already running**.
///
/// The other direction of widening, and a separate flow rather than a switch on the same one,
/// because what it does is not the mirror image of what widening does.
///
/// **It stops new connections and not the ones already running.** The name stops resolving and its
/// recorded addresses come out of the firewall, so nothing new can be reached — but the ruleset
/// accepts established traffic without consulting the set again, so a transfer in progress runs to
/// its end. Nothing here may say the host is unreachable: it is not, yet, and stopping a transfer
/// is what stopping the task does.
class Narrowing extends ChangeNotifier {
  /// Which task this is about, or null when nothing is being narrowed.
  Task? task;

  /// The names asked for, as typed.
  List<String> asking = const <String>[];

  /// How far the change goes. **Null until somebody picks one** — the daemon has no default, and
  /// narrowing only the run when somebody meant the project too leaves the next task starting
  /// with the host still open.
  Scope? scope;

  /// What the change would take back, or null when nothing has been previewed.
  Narrowed? preview;

  /// What the last change actually did.
  Narrowed? applied;

  /// Whether something is being asked right now.
  bool busy = false;

  /// Why it could not be done, in words.
  String? problem;

  /// Whether this task can be narrowed at all.
  ///
  /// The same two refusals as widening, and both knowable here — so the action is offered as
  /// unavailable with the reason rather than offered and refused.
  static String? whyNot(Task? task) {
    if (task == null) return 'no work is selected';
    if (!task.running) return 'it is not running, and there is no container to narrow';
    if (task.securityClass == 'offline') {
      return 'an offline project reaches nothing, so there is nothing to take back';
    }
    return null;
  }

  /// Opens it on one task, forgetting whatever was asked before.
  void open(Task task) {
    this.task = task;
    asking = const <String>[];
    scope = null;
    preview = null;
    applied = null;
    problem = null;
    notifyListeners();
  }

  /// Closes it.
  void close() {
    task = null;
    notifyListeners();
  }

  /// Takes what somebody typed and makes names of it.
  void ask(String typed) {
    asking = typed
        .split(RegExp(r'[\s,]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    preview = null;
    applied = null;
    notifyListeners();
  }

  /// Chooses how far the change goes.
  void choose(Scope chosen) {
    scope = chosen;
    preview = null;
    applied = null;
    notifyListeners();
  }

  /// Whether there is enough to ask with.
  bool get ready => asking.isNotEmpty && scope != null;

  /// Works out what it would take back, taking nothing back.
  Future<void> consider(FleetBackend backend) async {
    final which = task;
    final how = scope;
    if (which == null || how == null || asking.isEmpty) return;
    applied = null;
    await _asking(() async {
      preview = await backend.narrowTask(which.name, asking, scope: how, dryRun: true);
    });
  }

  /// Takes back what was previewed, in the same words.
  Future<void> apply(FleetBackend backend) async {
    final which = task;
    final how = scope;
    if (which == null || how == null || asking.isEmpty) return;
    await _asking(() async {
      applied = await backend.narrowTask(which.name, asking, scope: how);
      preview = null;
    });
  }

  /// Puts a preview or a result away.
  void letItBe() {
    preview = null;
    applied = null;
    notifyListeners();
  }

  /// What to say about what happened, in one line.
  String get words {
    final said = applied;
    if (said == null) return '';
    if (!said.outcome.reached) {
      return '${said.outcome.label}. ${said.detail}'.trim();
    }
    final names = said.closes.length == 1 ? 'it' : 'them';
    // **Zero addresses is a real state, not a failure**: the name was granted and the container
    // never reached it, so nothing was in the set to take out. Saying "0 addresses" as though
    // something had gone wrong would send somebody looking for a fault that is not there.
    final removed = said.addresses == 0
        ? 'Nothing was in the firewall for $names — the name was granted and never reached.'
        : '${said.addresses} ${said.addresses == 1 ? 'address' : 'addresses'} came out of the '
            'firewall.';
    final file = said.persisted
        ? ' The project file is changed too, so the next task starts without them.'
        : '';
    return 'Taken back: ${said.closes.join(', ')}. $removed$file';
  }

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}.';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
