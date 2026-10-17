import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Whether a machine can actually run a task, and what it is short of.
///
/// **The question nobody could ask before.** Every dependency this reports fails far from its
/// cause — without `nft` a container comes up with no ruleset, without `git` the gate has no
/// mirror, without `nsenter` a clearance decision cannot reach a running task. Until this was on
/// the wire, a person learned about them by starting work and watching it behave strangely.
///
/// **Nothing here offers to fix anything, and that is a decision rather than a gap.** Preparing a
/// machine means installing packages and writing under `/etc` — root on the node, and exactly the
/// powers this product is built around not having. There is a second reason it could never have
/// worked from here: a machine that is not ready usually has no daemon to ask, so a check
/// delivered over the daemon's socket can only ever answer for a machine whose daemon is already
/// up. What this shows instead is the single next action, which the daemon already names.
class HostReadiness extends ChangeNotifier {
  /// What the machine last said about itself, or null before it has been asked.
  Health? health;

  /// Whether it is being asked right now.
  bool busy = false;

  /// Why it could not be asked, in words.
  String? problem;

  /// Whether the machine runs tasks at all. Null until it has said.
  bool? get ready => health?.ready;

  /// What is not fine, which is what somebody came to read.
  List<Probe> get worthReading => health?.worthReading ?? const <Probe>[];

  /// Everything that was probed.
  List<Probe> get probes => health?.probes ?? const <Probe>[];

  /// What to say in one line, for a place that has room for one.
  String get verdict {
    final said = health;
    if (said == null) return '';
    if (!said.ready) {
      final stopping = said.probes.where((probe) => probe.stopsIt).length;
      return stopping == 1
          ? 'This machine cannot run work: one thing it needs is missing.'
          : 'This machine cannot run work: $stopping things it needs are missing.';
    }
    if (said.readyWithCaveats) {
      // **Ready and worth reading are not the same answer.** Degraded and unknown leave a machine
      // running tasks, and rounding either up to "fine" hides the thing somebody would want to
      // know before wondering why a run behaved oddly.
      final caveats = said.worthReading.length;
      return caveats == 1
          ? 'This machine runs work. One thing is worth knowing about.'
          : 'This machine runs work. $caveats things are worth knowing about.';
    }
    return 'This machine can run work. Nothing is missing.';
  }

  /// Asks the machine whether it can run anything.
  Future<void> look(FleetBackend backend) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      health = await backend.doctor();
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}.';
    } on FeatureNotSupported catch (ex) {
      // A daemon older than `Doctor`. Saying so beats an empty screen that reads as a machine
      // with nothing wrong.
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Forgets what was read, for a switch to another machine.
  void letItBe() {
    health = null;
    problem = null;
    notifyListeners();
  }
}
