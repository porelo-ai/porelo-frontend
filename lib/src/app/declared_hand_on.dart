import 'package:flutter/foundation.dart';

/// What a hand-over of the declared token, started by itself for a host's waiting projects, came to.
enum HandOnOutcome {
  /// Porelo handed the entry this computer's Porelo-Vault declares on, and the host took it.
  handedOn,

  /// This computer's Porelo-Vault answered that it declares no token for the forge: the person is asked.
  notDeclared,

  /// The host waits for no token now, by Porelo's exit code: there was nothing to do.
  nothingWaits,

  /// The hand-over ran and Porelo or the host refused the token, for the reason in its words.
  refused,

  /// The hand-over could not run: the host not reached, the Porelo-Vault not asked, a press giving to the same host
  /// meanwhile, or the token's step busy. That is no answer: the same wait is handed on again on the next word.
  notRun;

  /// Whether a hand-over that came to this answered the wait, so it is not handed on again by itself.
  bool get answers => this != notRun;
}

/// One hand-over's outcome, with its words where it was refused or could not run.
@immutable
class HandOn {
  /// Keeps the outcome and its words.
  const HandOn(this.outcome, {this.words, this.earlier = false});

  /// What it came to.
  final HandOnOutcome outcome;

  /// Why it was refused or could not run, in the person's words; null otherwise.
  final String? words;

  /// Whether this is what a hand-over for the same wait came to before, not one run now.
  final bool earlier;

  /// This outcome as an earlier hand-over's.
  HandOn get asEarlier => HandOn(outcome, words: words, earlier: true);
}

/// Where [DeclaredHandOn] reads the time from when it is given no clock; a test sets it and puts it back.
@visibleForTesting
DateTime Function() declaredHandOnClock = DateTime.now;

/// Hands a host the token this computer's Porelo-Vault declares, by itself, once per wait: once for the projects heard
/// waiting together, joined by whoever asks while it runs, and not again for a project until the host reports it
/// taken ([taken]), whatever it passes through meanwhile, so a token that did not help is not handed on in a loop. A
/// hand-over that could not run answers nothing; it is tried again for that host at most once per [retryAfter].
///
/// One hand-over serves every project the host waits on at that moment, so one per host is enough.
class DeclaredHandOn extends ChangeNotifier {
  /// Hands on with the given function, which answers what one hand-over to a host came to.
  DeclaredHandOn(this._give, {DateTime Function()? now, this.retryAfter = const Duration(minutes: 1)})
    : _now = now ?? (() => declaredHandOnClock());

  final Future<HandOn> Function(String host) _give;
  final DateTime Function() _now;

  /// How long after a hand-over to a host could not run the next is tried; until then the one that could not run is
  /// answered again, as [HandOn.earlier].
  final Duration retryAfter;

  /// The last hand-over to each host that could not run, with when it ended.
  final _notRun = <String, (DateTime, HandOn)>{};

  /// What the hand-over that answered each project's wait came to, by host and project.
  final _answered = <String, Map<String, HandOn>>{};
  final _running = <String, Future<HandOn>>{};
  final _runningFor = <String, Set<String>>{};
  bool _disposed = false;

  /// Whether a hand-over to [host] runs now.
  bool running(String host) => _running.containsKey(host);

  /// Hands [host] the declared token for [waiting], the projects heard waiting for it, unless a hand-over answered
  /// each of their waits before: then answers what that one came to, as [HandOn.earlier]. Joins a hand-over to [host]
  /// that runs already.
  Future<HandOn> forWaits(String host, Set<String> waiting) {
    if (_running[host] case final running?) {
      _runningFor[host]!.addAll(waiting);
      return running;
    }
    if (waiting.isEmpty) return Future.value(const HandOn(HandOnOutcome.nothingWaits));
    final answered = _answered[host] ?? const <String, HandOn>{};
    if (answered.keys.toSet().containsAll(waiting)) return Future.value(answered[waiting.first]!.asEarlier);
    if (_notRun[host] case (final at, final done) when _now().difference(at) < retryAfter) {
      return Future.value(done.asEarlier);
    }
    _runningFor[host] = {...waiting};
    final run = _run(host);
    _running[host] = run;
    notifyListeners();
    return run;
  }

  Future<HandOn> _run(String host) async {
    HandOn done;
    try {
      done = await _give(host);
    } on Exception catch (error) {
      done = HandOn(HandOnOutcome.notRun, words: '$error');
    }
    final projects = _runningFor.remove(host) ?? const <String>{};
    _running.remove(host);
    if (done.outcome.answers) {
      _notRun.remove(host);
      (_answered[host] ??= {}).addAll({for (final project in projects) project: done});
    } else {
      _notRun[host] = (_now(), done);
    }
    if (!_disposed) notifyListeners();
    return done;
  }

  /// Takes [projects], those [host] reports taken (carried): a later wait of one of them is a new wait. A project
  /// merely not waiting in one word of the host, as while it clones, keeps its wait answered.
  void taken(String host, Set<String> projects) =>
      _answered[host]?.removeWhere((project, _) => projects.contains(project));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
