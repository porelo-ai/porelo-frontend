import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'quiet_after_dispose.dart';

/// One sign-in of one agent on one machine, as that machine's own login task: asked whether it is needed, started
/// or found running, waited on, ended on purpose, or left to go on.
///
/// **Nothing is signed in here.** The login task runs on the machine; the person follows its link and pastes its
/// code in that task's terminal, which [openTheLoginTask] opens. No code and no secret pass through this program.
///
/// **Nothing starts on it either**: [onSignedIn] is told once the machine says signed in, so whoever owns this asks
/// again whether work can start; a start is always the person's press.
class SigningIn extends ChangeNotifier with QuietAfterDispose {
  /// The machine it signs in on, by the backend it asks; null until [ask] or [take].
  FleetBackend? get on => _on;
  FleetBackend? _on;

  /// The machine's name, for the sentences; set by whoever shows it.
  String machine = 'the machine';

  /// The agent, by the name `Agents` reports; null until [ask] or [take].
  String? get agent => _agent;
  String? _agent;

  /// What to call the agent for a person.
  String get who => _label.isNotEmpty ? _label : (_agent ?? 'the agent');
  String _label = '';

  /// Whether the machine has sign-ins of its own: null until it answered, false from one older than them, where a
  /// start goes as before.
  bool? served;

  /// The machine's latest word for it (`SIGNED_IN`, `NOT_SIGNED_IN`, `SIGNING_IN`, `VAULT_SHUT`, `CANNOT_SIGN_IN`,
  /// or one this build does not know), verbatim; null while it said none.
  String? state;

  /// The login task of the sign-in that runs, by the name every task call takes; null where none is known.
  String? loginTask;

  /// Whether the machine is being asked whether it is signed in.
  bool asking = false;

  /// Whether a sign-in is being started.
  bool starting = false;

  /// Whether a sign-in that runs is being waited on.
  bool get waiting => _wait != null;

  /// Whether the login task is being ended.
  bool ending = false;

  /// What is said of it now, or null where nothing is.
  String? words;

  /// Whether the machine still says, for a start, that what the agent signs in with is missing, whatever this
  /// says: its answer to whether work can start wins. Set by whoever asks that, after every [ask].
  bool get heldByCanStart => _heldByCanStart;
  set heldByCanStart(bool held) {
    if (held == _heldByCanStart) return;
    _heldByCanStart = held;
    notifyListeners();
  }

  bool _heldByCanStart = false;

  /// Whether [onSignedIn] is still out after the machine said signed in: the start stays held until whether work
  /// can start is asked again.
  bool _confirming = false;

  /// Opens the terminal of the login task named on the machine, as any task's; set by whoever shows it.
  Future<void> Function(String task)? openTheLoginTask;

  /// Told once the machine says signed in, so whether work can start is asked again.
  Future<void> Function()? onSignedIn;

  StreamSubscription<SignInWaited>? _wait;

  /// Counts the sign-ins, so an answer about an earlier one lands nowhere.
  int _turn = 0;

  /// Whether the login task was ended from here, so its end is said as that.
  bool _ended = false;

  /// Whether the machine says the agent is signed in, and nothing is still out.
  bool get signedIn => state == 'SIGNED_IN' && !asking && !starting && !waiting;

  /// Whether a start has to wait for it: **every answer but signed in holds it**, an unknown state, a refusal and a
  /// lost connection among them. A machine older than sign-ins holds nothing here.
  bool get holdsTheStart => served != false && (!signedIn || _heldByCanStart || _confirming);

  /// Whether a sign-in of it runs on the machine, as far as this knows.
  bool get running => loginTask != null && (waiting || state == 'SIGNING_IN');

  /// Why *Sign in* cannot run now, or null when it can.
  String? get whySignInCannot {
    if (_agent == null || _on == null) return 'no agent is chosen yet';
    if (served == false) return '$machine has no sign-in of its own; it needs a newer Porelo';
    if (asking) return '$machine is still asked whether $who is signed in';
    if (starting) return 'the sign-in is being started';
    if (ending) return 'the sign-in is being ended';
    if (state == 'SIGNED_IN' && !waiting && !heldByCanStart) return '$who is signed in on $machine';
    if (state == 'VAULT_SHUT') return 'the vault on $machine is shut';
    if (state == 'CANNOT_SIGN_IN' || state == _noSuchAgent) return '$machine cannot sign $who in';
    return null;
  }

  /// Why *End the sign-in* cannot run now, or null when it can.
  String? get whyEndCannot {
    if (ending) return 'the sign-in is being ended';
    if (!running) return 'no sign-in of $who runs on $machine';
    return null;
  }

  /// Drops everything about the sign-in before; **a login task that runs is not ended**.
  void forget() {
    _turn++;
    unawaited(_wait?.cancel());
    _wait = null;
    _on = null;
    _agent = null;
    _label = '';
    served = null;
    state = null;
    loginTask = null;
    asking = false;
    starting = false;
    ending = false;
    words = null;
    _heldByCanStart = false;
    _confirming = false;
    _ended = false;
    notifyListeners();
  }

  /// Leaves it: the wait is dropped, and **the login task goes on**. Answers what to say of that, or null where no
  /// sign-in runs.
  String? leave() {
    final left = running ? 'The sign-in to $who goes on in its own task on $machine.' : null;
    _turn++;
    _confirming = false;
    unawaited(_wait?.cancel());
    _wait = null;
    notifyListeners();
    return left;
  }

  /// Asks [on] whether [agent] is signed in there, unless that is what it holds already; [label] is what to call it.
  Future<void> ask(FleetBackend on, {required String agent, String label = ''}) async {
    if (identical(on, _on) && agent == _agent) return;
    forget();
    _on = on;
    _agent = agent;
    _label = label;
    asking = true;
    notifyListeners();
    final turn = _turn;
    try {
      final listed = await on.agentSignIns(agents: <String>[agent]);
      if (turn != _turn) return;
      final its = listed.where((each) => each.agent == agent).firstOrNull;
      served = true;
      asking = false;
      if (its == null) {
        words = '$machine did not say whether $who is signed in there, so nothing starts yet.';
        notifyListeners();
        return;
      }
      _taken(its);
    } on FeatureNotSupported {
      if (turn != _turn) return;
      served = false;
      asking = false;
      notifyListeners();
    } on Exception catch (failed) {
      if (turn != _turn) return;
      served = true;
      asking = false;
      _refused(failed, 'whether $who is signed in');
    }
  }

  /// Takes what the machine said of [agent] in a list asked for several, on [on].
  void take(FleetBackend on, AgentSignIn its, {String label = ''}) {
    forget();
    _on = on;
    _agent = its.agent;
    _label = label;
    served = true;
    _taken(its);
  }

  /// Takes it as one where the machine did not say, on [on]: held, with *Sign in* offered.
  void unsaid(FleetBackend on, String agent, {String label = ''}) {
    forget();
    _on = on;
    _agent = agent;
    _label = label;
    served = true;
    words = '$machine did not say whether $who is signed in there, so nothing starts yet.';
    notifyListeners();
  }

  /// Takes what the machine said of it as it is, and begins waiting on one that runs.
  void _taken(AgentSignIn its) {
    state = its.state;
    loginTask = its.loginTask;
    words = switch (its.state) {
      'SIGNED_IN' => null,
      'NOT_SIGNED_IN' => 'Sign in to $who on $machine before work starts there.',
      'SIGNING_IN' => 'Another sign-in to $who on $machine is running; waiting for it.',
      'VAULT_SHUT' => _vaultShut,
      'CANNOT_SIGN_IN' => '$machine says $who cannot be signed in there, so nothing starts.',
      '' => '$machine did not say whether $who is signed in there, so nothing starts yet.',
      final other => '$machine says the sign-in to $who is $other; nothing starts until it says signed in.',
    };
    notifyListeners();
    if (its.state == 'SIGNING_IN') _waitOn();
  }

  String get _vaultShut => 'The vault on $machine is shut, so nothing can be signed in or started.';

  static const String _noSuchAgent = 'NO_SUCH_AGENT';

  /// Signs it in: starts the machine's login task, or finds the one that runs, opens its terminal and waits on it.
  /// **Never a second login task**: one known to run is only opened and waited on.
  Future<void> signIn() async {
    final on = _on;
    final agent = _agent;
    if (on == null || agent == null || whySignInCannot != null) return;
    final running = loginTask;
    if (running != null && this.running) {
      final open = openTheLoginTask;
      if (open != null) unawaited(open(running));
      if (!waiting) _waitOn();
      return;
    }
    final turn = ++_turn;
    _ended = false;
    starting = true;
    words = null;
    notifyListeners();
    try {
      final started = await on.agentSignInStart(agent);
      if (turn != _turn) return;
      starting = false;
      if (started.task.isEmpty) {
        words = '$machine did not name the task its sign-in runs in, so it cannot be opened here.';
        notifyListeners();
        return;
      }
      loginTask = started.task;
      state = 'SIGNING_IN';
      words = started.started
          ? 'Follow the link in the terminal of ${started.task} on $machine and sign in there; this waits for it.'
          : 'Another sign-in to $who on $machine is running, in ${started.task}; waiting for it.';
      _waitOn();
      final open = openTheLoginTask;
      if (open != null) unawaited(open(started.task));
    } on CannotSignIn catch (refused) {
      if (turn != _turn) return;
      starting = false;
      state = 'CANNOT_SIGN_IN';
      words = refused.reason.isEmpty ? '$machine cannot sign $who in.' : refused.reason;
      notifyListeners();
    } on NoSuchAgent {
      if (turn != _turn) return;
      starting = false;
      state = _noSuchAgent;
      words = '$who is not installed on $machine.';
      notifyListeners();
    } on VaultShut {
      if (turn != _turn) return;
      starting = false;
      state = 'VAULT_SHUT';
      words = _vaultShut;
      notifyListeners();
    } on Exception catch (failed) {
      if (turn != _turn) return;
      starting = false;
      _refused(failed, 'how $who is signed in');
    }
  }

  /// Waits on the sign-in that runs, until the machine's final reply.
  void _waitOn() {
    final on = _on;
    final agent = _agent;
    if (on == null || agent == null) return;
    final turn = _turn;
    SignInWaited? last;
    unawaited(_wait?.cancel());
    _wait = on
        .agentSignInWait(agent)
        .listen(
          (reply) {
            if (turn == _turn) last = reply;
          },
          onError: (Object failed) {
            if (turn != _turn) return;
            _wait = null;
            state = null;
            _refused(failed, 'how the sign-in of $who ended');
          },
          onDone: () {
            if (turn != _turn) return;
            _wait = null;
            _waitEnded(last);
          },
          cancelOnError: true,
        );
    notifyListeners();
  }

  void _waitEnded(SignInWaited? reply) {
    final ended = _ended;
    _ended = false;
    // **A wait ends only on a final reply**: one that ends on a sign-in still running did not say how it ended.
    final last = reply?.state == 'SIGNING_IN' ? null : reply;
    state = last?.state;
    loginTask = null;
    words = switch (last?.state) {
      'SIGNED_IN' => 'Signed in to $who on $machine.',
      'NOT_SIGNED_IN' when ended => 'The sign-in to $who on $machine was ended; nothing starts.',
      'NOT_SIGNED_IN' =>
        '${last!.detail ?? 'The sign-in to $who on $machine ended without signing in.'} Sign in again to try once more.',
      'VAULT_SHUT' => _vaultShut,
      null => '$machine did not say how the sign-in of $who ended, so nothing starts.',
      final other => '$machine says the sign-in to $who is $other; nothing starts until it says signed in.',
    };
    final signedIn = last?.state == 'SIGNED_IN' ? onSignedIn : null;
    if (signedIn == null) return notifyListeners();
    // Held until whether work can start is asked again: signed in alone never offers a start.
    _confirming = true;
    notifyListeners();
    final turn = _turn;
    unawaited(() async {
      try {
        await signedIn();
      } finally {
        if (turn == _turn) {
          _confirming = false;
          notifyListeners();
        }
      }
    }());
  }

  /// Ends the sign-in that runs by stopping its login task, as any task is stopped. Nothing starts after it.
  Future<void> end() async {
    final on = _on;
    final task = loginTask;
    if (on == null || task == null || whyEndCannot != null) return;
    final turn = _turn;
    ending = true;
    _ended = true;
    notifyListeners();
    try {
      await on.stopTask(task);
      if (turn != _turn) return;
      ending = false;
      if (!waiting) {
        loginTask = null;
        state = 'NOT_SIGNED_IN';
        words = 'The sign-in to $who on $machine was ended; nothing starts.';
      }
      notifyListeners();
    } on Exception catch (failed) {
      if (turn != _turn) return;
      ending = false;
      _ended = false;
      _refused(failed, 'whether the sign-in of $who was ended');
    }
  }

  /// Says why the machine did not answer, in its words; the start stays held.
  void _refused(Object failed, String what) {
    words = switch (failed) {
      VaultShut() => _vaultShut,
      VarlinkDisconnected(:final message) => 'Lost contact with $machine: $message. Nothing starts until it answers.',
      FeatureNotSupported() => '$machine could not say $what: it needs a newer Porelo.',
      VarlinkException(:final parameters, :final simpleName) =>
        '$machine could not say $what: ${parameters['message'] ?? parameters['detail'] ?? simpleName}',
      _ => '$machine could not say $what: $failed',
    };
    if (failed is VaultShut) state = 'VAULT_SHUT';
    notifyListeners();
  }

  @override
  void dispose() {
    _turn++;
    unawaited(_wait?.cancel());
    _wait = null;
    super.dispose();
  }
}
