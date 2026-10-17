import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Blocked connections from every task on one machine, as they happen.
///
/// **The one place in the interface where latency costs something real.** A task is stopped while
/// its question goes unanswered and the watcher gives up on its own timeout, so this is a stream
/// and never a poll — and a machine nobody is connected to is one whose questions expire unseen.
///
/// One subscription covers every task, including tasks started after it, so there is one view of
/// the machine rather than one view per piece of work.
class Clearance extends ChangeNotifier {
  final Map<String, Prompt> _asking = <String, Prompt>{};
  final List<Prompt> _settled = <Prompt>[];
  final Set<String> _answering = <String>{};
  StreamSubscription<Prompt>? _listening;
  bool _disposed = false;

  /// Why the stream stopped, or null while it is running.
  String? problem;

  /// What is waiting for an answer, oldest question first.
  List<Prompt> get waiting => _asking.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  /// How many are waiting.
  int get count => _asking.length;

  /// What has been settled, newest first, so an answer that arrived while nobody looked is still
  /// findable — including one that ran out.
  List<Prompt> get settled => _settled.reversed.toList();

  /// Whether an answer for this one has been sent and not yet echoed back.
  bool answering(Prompt prompt) => _answering.contains(prompt.identity);

  /// Whether the same destination has already been let through for the same task.
  ///
  /// A decision is remembered per **address**, not per name, and it survives a resume — so one
  /// fixed address is asked about once for the whole run, while a CDN or anything round-robin
  /// asks again for every new address it resolves to. Saying so beats leaving somebody to
  /// conclude their last answer was ignored.
  bool askedBefore(Prompt prompt) => _settled.any(
    (each) => each.task == prompt.task && each.destination == prompt.destination && each.verdict == 'allow',
  );

  /// Starts watching. Safe to call again; it replaces what was watching before.
  void watch(FleetBackend backend) {
    _listening?.cancel();
    problem = null;
    _listening = backend.prompts().listen(
      _arrived,
      onError: (Object error) {
        // An older daemon has no Prompts; that disables this one feature and nothing else.
        problem = error is FeatureNotSupported ? 'This backend cannot report blocked connections.' : '$error';
        _notify();
      },
    );
  }

  /// Answers one, and leaves it on screen until the stream confirms it.
  ///
  /// Not removed optimistically: the answer is only real once whatever asked has taken it, and a
  /// row that vanished on the press would claim something nobody had confirmed.
  Future<void> decide(FleetBackend backend, Prompt prompt, {required bool allow}) async {
    _answering.add(prompt.identity);
    _notify();
    try {
      await backend.decide(prompt, allow: allow);
    } on VarlinkException catch (refusal) {
      _answering.remove(prompt.identity);
      // A task that is not running has no watcher to tell, and that is refused rather than
      // accepted and dropped — an answer that goes nowhere would leave somebody believing they
      // had unblocked something.
      problem = refusal.simpleName == 'NoClearance'
          ? '${prompt.task} is no longer running, so nothing could be told.'
          : 'Refused: ${refusal.simpleName}.';
      _asking.remove(prompt.identity);
      _notify();
    } on VarlinkDisconnected catch (ex) {
      _answering.remove(prompt.identity);
      problem = 'Lost contact before it could be told: ${ex.message}';
      _notify();
    }
  }

  /// Puts a settled one away.
  void forget(Prompt prompt) {
    _settled.removeWhere((each) => each.identity == prompt.identity);
    _notify();
  }

  /// How many questions the machine dropped unseen since this was last marked seen.
  int missed = 0;

  /// Marks the dropped questions seen.
  void missedSeen() {
    missed = 0;
    _notify();
  }

  void _arrived(Prompt prompt) {
    if (prompt.missed > 0) {
      missed += prompt.missed;
      _notify();
      // A reply that only says how many were dropped asks nothing itself.
      if (prompt.task.isEmpty) return;
    }
    if (prompt.settled) {
      // The answer to a question, arriving as the same destination a second time. Matched by task
      // and key alone — `at` carries the decision time here rather than the block time, and
      // `prefix` is empty — so anything keyed on those would show every destination twice.
      _asking.remove(prompt.identity);
      _answering.remove(prompt.identity);
      _settled
        ..removeWhere((each) => each.identity == prompt.identity)
        ..add(prompt);
      if (_settled.length > 20) _settled.removeAt(0);
    } else {
      _asking[prompt.identity] = prompt;
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listening?.cancel();
    super.dispose();
  }
}
