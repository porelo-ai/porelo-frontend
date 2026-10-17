import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Cutting every form of access at once, for the moment somebody knows something is wrong and
/// does not yet know what.
///
/// **Speed is the whole feature.** Anything that takes more than one action is not an emergency
/// stop — so this is one call, reached from a button that is always on screen, from the finder and
/// from the keyboard.
///
/// And it **stops without removing**. Every workspace, log and unpushed commit survives, and
/// `Start` brings a task back with the work it had. What this reports is therefore *what
/// survived*, never what was cleared away: somebody who read it as a cleanup would spend an
/// afternoon looking for work that is exactly where they left it.
class EmergencyStop extends ChangeNotifier {
  /// What it would stop, asked for before anything is stopped.
  Panicked? preview;

  /// What it did.
  Panicked? done;

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Why it could not be done, in words.
  String? problem;

  /// Whether anything is on screen about it.
  bool get open => preview != null || done != null || problem != null;

  bool _disposed = false;

  /// Asks what would be stopped, stopping nothing.
  ///
  /// Shown before the button that does it. This is the most consequential action in the product
  /// and the one most likely to be pressed by somebody who is not sure — so what it would do is
  /// the thing they agree to.
  Future<void> consider(FleetBackend backend) async {
    done = null;
    await _asking(() async {
      preview = await backend.panic(dryRun: true);
    });
  }

  /// Stops everything.
  Future<void> stopEverything(FleetBackend backend) async {
    await _asking(() async {
      done = await backend.panic();
      preview = null;
    });
  }

  /// Puts what is on screen away.
  void letItBe() {
    preview = null;
    done = null;
    problem = null;
    notifyListeners();
  }

  /// What to say about what it did, in one line.
  ///
  /// *"the N that were running"*, never *"N of M"*: a task that was already stopped is not in the
  /// answer at all, so a total would be one this call never saw — and somebody reading *"3 of 7"*
  /// goes looking for what happened to the other four.
  String get words {
    final result = done;
    if (result == null) return '';
    final work = result.stopped == 1 ? 'the one that was' : 'the ${result.stopped} that were';
    return 'Stopped $work running. Nothing was removed.';
  }

  /// The way back, named rather than left to be worked out.
  ///
  /// Recovery is `Start`, and it is possible precisely because nothing was removed. The steps are
  /// named because somebody reading this has just had a bad minute.
  List<String> get howToRecover => const <String>[
        'Find what went wrong. Every log is where it was.',
        'Start each piece of work again from its row — it comes back with the workspace, '
            'the branch and the commits it had.',
        'Anything that was waiting at the gate is still waiting there.',
      ];

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}. '
          'Nothing was stopped, and work is still running.';
    } on FeatureNotSupported catch (ex) {
      // A backend older than `Panic`. Saying so beats a button that quietly does nothing at the
      // one moment somebody needs it to do everything.
      problem = '$ex';
    } finally {
      busy = false;
      // A dialog put away while a slow machine was still answering has already disposed this.
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
