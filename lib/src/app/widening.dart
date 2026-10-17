import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Letting a task that is **already running** reach something it could not reach before.
///
/// The counterpart to the project egress editor, which edits a file the next task reads. This one
/// lands on work in front of somebody, which makes it the more consequential of the two: it is
/// previewed every time, and the scope is chosen rather than defaulted.
///
/// What it deliberately cannot do is narrow. Taking a grant back from a container that already has
/// it is the first thing of its kind in the product and is not decided, so there is no method and
/// no control.
class Widening extends ChangeNotifier {
  /// Which task this is about, or null when nothing is being widened.
  Task? task;

  /// The names asked for, as typed.
  List<String> asking = const <String>[];

  /// How far the change should go. **Null until somebody picks one**, because the daemon has no
  /// default and neither should the screen: "this run" and "this project" are different
  /// intentions.
  Scope? scope;

  /// What the change would grant, or null when nothing has been previewed.
  Widened? preview;

  /// What the last change actually did.
  Widened? applied;

  /// Whether something is being asked for right now.
  bool busy = false;

  /// Why it could not be done, in words. Null when nothing is wrong.
  String? problem;

  /// Whether this task can be widened at all.
  ///
  /// A stopped task has no container to reach into, and an offline project's tasks reach nothing
  /// by design. Both are refusals the daemon would give — `NOT_RUNNING` and `REFUSED_BY_CLASS` —
  /// and both are knowable here, so the action is disabled with a reason instead of offered and
  /// refused.
  static String? whyNot(Task? task) {
    if (task == null) return 'no work is selected';
    if (!task.running) return 'it is not running, and there is no container to widen';
    if (task.securityClass == 'offline') {
      return 'an offline project reaches nothing, and this is not a way around that';
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
  ///
  /// Split on commas and whitespace, because both are what people type into a list of hosts, and
  /// emptied of blanks so a trailing comma is not a name.
  void ask(String typed) {
    asking = typed
        .split(RegExp(r'[\s,]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    // Names changed, so what was previewed is no longer what would happen.
    preview = null;
    applied = null;
    notifyListeners();
  }

  /// Chooses how far the change goes.
  void choose(Scope chosen) {
    scope = chosen;
    // The scope is part of what a preview says, so an old preview is stale once it changes.
    preview = null;
    applied = null;
    notifyListeners();
  }

  /// Whether there is enough to ask with: names, and a scope somebody picked.
  bool get ready => asking.isNotEmpty && scope != null;

  /// Works out what the change would grant, without granting it.
  Future<void> consider(FleetBackend backend) async {
    final which = task;
    final how = scope;
    if (which == null || how == null || asking.isEmpty) return;
    applied = null;
    await _asking(() async {
      preview = await backend.widenTask(which.name, asking, scope: how, dryRun: true);
    });
  }

  /// Grants what was previewed.
  ///
  /// The same names and the same scope, passed again rather than remembered as a promise: what
  /// somebody agreed to is the preview, and asking twice in the same words is what makes it the
  /// same change.
  Future<void> apply(FleetBackend backend) async {
    final which = task;
    final how = scope;
    if (which == null || how == null || asking.isEmpty) return;
    await _asking(() async {
      applied = await backend.widenTask(which.name, asking, scope: how);
      preview = null;
    });
  }

  /// Puts a preview or a result away.
  void letItBe() {
    preview = null;
    applied = null;
    notifyListeners();
  }

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      problem = _wordsFor(refusal);
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      // A backend older than `WidenTask`. Saying so beats a control that quietly does nothing.
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _wordsFor(VarlinkException refusal) => switch (refusal.simpleName) {
        // Only reachable if this code stopped sending one, which is why it names the cause rather
        // than asking a person to pick again.
        'ScopeRequired' =>
          'No scope was sent. This run and this project are different changes and the '
              'daemon will not choose between them.',
        _ => 'Refused: ${refusal.simpleName}.',
      };
}
