import 'package:flutter/foundation.dart';

/// What a hand-over of the declared token, started by itself for a host's waiting projects, came to.
enum HandOnOutcome {
  /// Porelo handed the entry this computer's Porelo-Vault declares on, and the host took it.
  handedOn,

  /// This computer's Porelo-Vault declares no token for the forge, or could not be asked: the person is asked.
  notDeclared,

  /// The host waits for no token now: there was nothing to do.
  nothingWaits,

  /// These waits were answered by a hand-over before: one that did not help is never handed on again by itself.
  answeredBefore,

  /// The hand-over did not go through, for the reason in its words.
  refused,
}

/// One hand-over's outcome, with its words where it was refused.
@immutable
class HandOn {
  /// Keeps the outcome and its words.
  const HandOn(this.outcome, {this.words});

  /// What it came to.
  final HandOnOutcome outcome;

  /// Why it was refused, in the person's words; null otherwise.
  final String? words;
}

/// Hands a host the token this computer's Porelo-Vault declares, by itself, once per wait: once for the projects heard
/// waiting together, joined by whoever asks while it runs, and never again for a project it was handed on for, so a
/// token that did not help is not handed on in a loop. A project heard waiting later is a new wait.
///
/// One hand-over serves every project the host waits on at that moment, so one per host is enough.
class DeclaredHandOn extends ChangeNotifier {
  /// Hands on with the given function, which answers what one hand-over to a host came to.
  DeclaredHandOn(this._give);

  final Future<HandOn> Function(String host) _give;
  final _answered = <String, Set<String>>{};
  final _running = <String, Future<HandOn>>{};

  /// Whether a hand-over to [host] runs now.
  bool running(String host) => _running.containsKey(host);

  /// Hands [host] the declared token for [waiting], the projects heard waiting for it, unless every one of them was
  /// handed on for before; joins a hand-over to [host] that runs already.
  Future<HandOn> forWaits(String host, Set<String> waiting) {
    if (_running[host] case final running?) return running;
    final answered = _answered[host] ?? const <String>{};
    if (waiting.isEmpty || answered.containsAll(waiting)) {
      return Future.value(const HandOn(HandOnOutcome.answeredBefore));
    }
    _answered[host] = {...answered, ...waiting};
    final run = _give(host).whenComplete(() {
      _running.remove(host);
      notifyListeners();
    });
    _running[host] = run;
    notifyListeners();
    return run;
  }
}
