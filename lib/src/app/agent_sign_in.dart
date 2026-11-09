import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'quiet_after_dispose.dart';

/// One sign-in of one agent on one machine, as that machine's own login: asked whether it is needed, started or
/// found running, attached to in a terminal on that machine, waited on, or left to go on.
///
/// **Nothing is signed in here.** The login runs in a container on the machine; the person follows its link and
/// pastes its code in the terminal [attachHere] opens there. No code and no secret pass through this program.
///
/// **Nothing starts on it either**: [onSignedIn] is told once the machine says the credential is stored, so whoever
/// owns this asks again whether work can start; a start is always the person's press.
class SigningIn extends ChangeNotifier with QuietAfterDispose {
  /// The machine it signs in on, by the backend it asks; null until [ask] or [take].
  FleetBackend? get on => _on;
  FleetBackend? _on;

  /// The machine's name, for the sentences; set by whoever shows it.
  String machine = 'the machine';

  /// Whether the person reaches the machine from another one (any machine this window reaches over ssh), so the
  /// machine refuses a sign-in whose reply would come back to itself; set by whoever shows it.
  bool remote = false;

  /// Why no terminal can be opened on the machine from here, or null where one can; set by whoever shows it.
  String? cannotAttach;

  /// The agent, by the name `Agents` reports; null until [ask] or [take].
  String? get agent => _agent;
  String? _agent;

  /// What to call the agent for a person.
  String get who => _label.isNotEmpty ? _label : (_agent ?? 'the agent');
  String _label = '';

  /// Whether the machine has sign-ins of its own: null until it answered, false from one older than them, where a
  /// start goes as before.
  bool? served;

  /// The machine's latest word for it (`SIGNED_IN`, `NOT_SIGNED_IN`, `VAULT_LOCKED`, `CANNOT_SAY`, or one this build
  /// does not know), verbatim; null while it said none.
  String? state;

  /// The container of the sign-in that runs, `""` while one is being prepared; null where none is known to run.
  String? container;

  /// Why the machine refused to start the sign-in (`ALREADY_SIGNED_IN`, `LOOPBACK_OVER_SSH`, or another, verbatim),
  /// or null where it did not.
  String? refusal;

  /// Whether the machine is being asked whether it is signed in.
  bool asking = false;

  /// Whether a sign-in is being started.
  bool starting = false;

  /// Whether the sign-in the machine found is being imported.
  bool importing = false;

  /// Whether a sign-in that runs is being waited on.
  bool get waiting => _wait != null;

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

  /// Whether the machine's answer to whether work can start says it can, for this agent on this machine. Set by
  /// whoever asks that, after every [ask]: **only it lets a start through that the machine cannot say is signed in**.
  bool get startSaysReady => _startSaysReady;
  set startSaysReady(bool ready) {
    if (ready == _startSaysReady) return;
    _startSaysReady = ready;
    notifyListeners();
  }

  bool _startSaysReady = false;

  /// Whether the terminal attached to the sign-in is open here: pressed again, no second one is stacked on it.
  bool attaching = false;

  /// The login the wait is on, as the machine named it; null while none is waited on.
  String? _waitedOn;

  /// Whether [onSignedIn] is still out after the machine said signed in: the start stays held until whether work
  /// can start is asked again.
  bool _confirming = false;

  /// Runs what attaches to the login, as the machine named it, **on that machine** in a terminal; set by whoever shows it.
  Future<void> Function(List<String> attach)? attachHere;

  /// Told once the machine says signed in, so whether work can start is asked again.
  Future<void> Function()? onSignedIn;

  StreamSubscription<SignInWaited>? _wait;

  /// What attaches to the sign-in that runs, as the machine named it when it started or answered it; null where it
  /// has not named it.
  List<String>? _attach;

  /// Counts the sign-ins, so an answer about an earlier one lands nowhere.
  int _turn = 0;

  /// Whether the machine says the agent is signed in, and nothing is still out.
  bool get signedIn => state == 'SIGNED_IN' && _settled;

  bool get _settled => !asking && !starting && !importing && !waiting;

  /// Whether anything about it is still out on the machine: a question, a start, an import or a wait.
  bool get out => asking || starting || importing || waiting;

  /// Whether the machine cannot say whether the agent is signed in, as with a provider of its own it cannot use, and
  /// its answer to whether work can start says it can: **that answer decides**, since the start settles what the
  /// agent signs in with. No sign-in is offered for it.
  bool get startDecides =>
      const <String>{'CANNOT_SAY', 'NO_PROVIDER'}.contains(state) && _startSaysReady && !_heldByCanStart && _settled;

  /// Whether a start has to wait for it: **every answer but signed in holds it**, a shut vault, an unknown state, a
  /// refusal and a lost connection among them, and one the machine cannot say unless its answer for the start says
  /// work can start. A machine older than sign-ins holds nothing here.
  bool get holdsTheStart => served != false && (!(signedIn || startDecides) || _heldByCanStart || _confirming);

  /// Whether a sign-in of it runs on the machine, as far as this knows.
  bool get running => container != null;

  /// Whether the machine refused the sign-in because its own agent directory holds one: the import comes first, and
  /// a forced sign-in is the second decision.
  bool get alreadySignedIn => refusal == _alreadySignedIn;

  static const String _alreadySignedIn = 'ALREADY_SIGNED_IN';

  /// The refusals a press here cannot change.
  static const Set<String> _final = <String>{
    'NO_SUCH_AGENT',
    'UNSUPPORTED',
    'LOOPBACK_OVER_SSH',
    'NO_CONFIG_DIRECTORY',
    'NO_PROVIDER',
  };

  String? get _busy {
    if (_agent == null || _on == null) return 'no agent is chosen yet';
    if (served == false) return '$machine has no sign-in of its own; it needs a newer Porelo';
    if (asking) return '$machine is still asked whether $who is signed in';
    if (starting) return 'the sign-in is being started';
    if (importing) return 'the sign-in found on $machine is being imported';
    return null;
  }

  /// Why *Sign in* cannot run now, or null when it can.
  String? get whySignInCannot {
    if (_busy case final busy?) return busy;
    if (attaching) return 'the terminal of the sign-in to $who is open';
    if (state == 'SIGNED_IN' && !waiting && !heldByCanStart) return '$who is signed in on $machine';
    if (startDecides) return '$machine cannot say whether $who is signed in, and says work can start';
    if (state == 'VAULT_LOCKED') return 'the vault on $machine is shut';
    if (alreadySignedIn) return '$machine holds a sign-in of $who already: import it, or sign in anyway';
    if (_final.contains(refusal)) return '$machine cannot sign $who in from here';
    if (cannotAttach case final why?) return why;
    return null;
  }

  /// Why *Sign in anyway* cannot run now, or null when it can: **only after the machine said it holds a sign-in**.
  String? get whySignInAnywayCannot {
    if (_busy case final busy?) return busy;
    if (attaching) return 'the terminal of the sign-in to $who is open';
    if (!alreadySignedIn) return '$machine has not said it holds a sign-in of $who';
    if (cannotAttach case final why?) return why;
    return null;
  }

  /// Why *Use the sign-in found on the machine* cannot run now, or null when it can.
  String? get whyImportCannot {
    if (_busy case final busy?) return busy;
    if (!alreadySignedIn) return '$machine has not said it holds a sign-in of $who';
    return null;
  }

  /// Drops everything about the sign-in before; **a sign-in that runs is not ended**.
  void forget() {
    _turn++;
    unawaited(_wait?.cancel());
    _wait = null;
    _waitedOn = null;
    attaching = false;
    _on = null;
    _agent = null;
    _label = '';
    served = null;
    state = null;
    container = null;
    _attach = null;
    refusal = null;
    asking = false;
    starting = false;
    importing = false;
    words = null;
    _heldByCanStart = false;
    _startSaysReady = false;
    _confirming = false;
    notifyListeners();
  }

  /// Leaves it: what is still out is dropped, a late answer opens no wait and no terminal, the wait's connection is
  /// closed, and **the sign-in goes on** on the machine, which only a terminal watched. Answers what to say of that,
  /// or null where no sign-in runs or starts.
  String? leave() {
    final left = running || starting
        ? 'The sign-in to $who goes on by itself on $machine until it is finished or 30 minutes pass; nothing starts '
              'from here.'
        : null;
    _turn++;
    _confirming = false;
    asking = false;
    starting = false;
    importing = false;
    attaching = false;
    unawaited(_wait?.cancel());
    _wait = null;
    _waitedOn = null;
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
      final listed = await on.agentSignIns();
      if (turn != _turn) return;
      served = true;
      asking = false;
      final its = listed.where((each) => each.agent == agent).firstOrNull;
      if (its == null) return _unsaid();
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

  /// Takes what the machine said of [its] agent in a list asked for all, on [on].
  void take(FleetBackend on, AgentSignIn its, {String label = ''}) {
    forget();
    _on = on;
    _agent = its.agent;
    _label = label;
    served = true;
    _taken(its);
  }

  /// Takes it as one the machine did not list, on [on]: held, with *Sign in* offered.
  void unsaid(FleetBackend on, String agent, {String label = ''}) {
    forget();
    _on = on;
    _agent = agent;
    _label = label;
    served = true;
    _unsaid();
  }

  void _unsaid() {
    words = '$machine did not say whether $who is signed in there, so nothing starts yet.';
    notifyListeners();
  }

  /// Takes what the machine said of it as it is, and begins waiting on one that runs.
  void _taken(AgentSignIn its) {
    state = its.state;
    container = its.running;
    words = its.running != null
        ? 'Another sign-in to $who on $machine is running; waiting for it. Sign in opens its terminal.'
        : switch (its.state) {
            'SIGNED_IN' => null,
            'NOT_SIGNED_IN' => 'Sign in to $who on $machine before work starts there.',
            'VAULT_LOCKED' => _vaultShut,
            'CANNOT_SAY' =>
              '$machine cannot say whether $who is signed in: its default provider cannot be used there. '
                  'Work starts only where $machine says it can.',
            '' => '$machine did not say whether $who is signed in there, so nothing starts yet.',
            final other => '$machine says the sign-in to $who is $other; nothing starts until it says signed in.',
          };
    notifyListeners();
    if (its.running != null) _waitOn();
  }

  String get _vaultShut => 'The vault on $machine is shut, so nothing can be signed in or started.';

  /// Signs it in: starts the machine's login, or has it answer the one that runs, attaches a terminal to it on that
  /// machine and waits on it. [force] is the person's second decision after the machine said it holds a sign-in.
  Future<void> signIn({bool force = false}) async {
    final on = _on;
    final agent = _agent;
    if (on == null || agent == null || (force ? whySignInAnywayCannot : whySignInCannot) != null) return;
    // One that runs and is waited on is only opened again: **never a second**, nor a second question for it.
    final known = _attach;
    if (!force && known != null && running && waiting) return _attachTo(known);
    // The same turn: a wait already out is kept, and only leaving or forgetting drops an answer.
    final turn = _turn;
    starting = true;
    refusal = null;
    words = null;
    notifyListeners();
    try {
      final started = await on.agentSignInStart(agent, force: force ? true : null, remote: remote ? true : null);
      if (turn != _turn) return;
      starting = false;
      container = started.container;
      _attach = started.attach.isEmpty ? null : started.attach;
      if (state == 'SIGNED_IN') state = null;
      words = started.attach.isEmpty
          ? '$machine did not say how to reach its sign-in of $who, so no terminal opens; this waits for it.'
          : started.started
          ? 'Sign in in the terminal on $machine; this waits for it.'
          : 'Another sign-in to $who on $machine was running; its terminal is opened, and this waits for it.';
      // Always on the login the machine named now: a wait on one before is dropped for it.
      if (!waiting || _waitedOn != started.container) _waitOn();
      notifyListeners();
      if (started.attach.isNotEmpty) _attachTo(started.attach);
    } on SignInRefused catch (refused) {
      if (turn != _turn) return;
      starting = false;
      refusal = refused.reason;
      if (refused.reason == 'VAULT_LOCKED') state = 'VAULT_LOCKED';
      // The machine's words, verbatim, where it gives them.
      final said = refused.detail.isNotEmpty ? refused.detail : '$machine refused to sign $who in: ${refused.reason}.';
      words = refused.reason == _alreadySignedIn
          ? '$said Use that sign-in first; a sign-in of its own is the other way.'
          : said;
      notifyListeners();
    } on Exception catch (failed) {
      if (turn != _turn) return;
      starting = false;
      _refused(failed, 'how $who is signed in');
    }
  }

  /// Opens the terminal attached to [argv] here, once: **pressed again while it is open, none is stacked on it**.
  void _attachTo(List<String> argv) {
    final attach = attachHere;
    if (attach == null || attaching) return;
    final turn = _turn;
    attaching = true;
    notifyListeners();
    unawaited(() async {
      try {
        await attach(argv);
      } finally {
        if (turn == _turn) {
          attaching = false;
          notifyListeners();
        }
      }
    }());
  }

  /// Imports the sign-in the machine found in its own agent directory, then asks it again whether [agent] is signed
  /// in: what is on screen is the machine's answer, never assumed from the import.
  Future<void> importTheSignIn() async {
    final on = _on;
    final agent = _agent;
    if (on == null || agent == null || whyImportCannot != null) return;
    final turn = _turn;
    importing = true;
    words = null;
    notifyListeners();
    try {
      final imported = await on.importCredential(agent: agent);
      if (turn != _turn) return;
      if (!imported.stored) {
        importing = false;
        words = imported.detail.isNotEmpty
            ? imported.detail
            : '$machine imported nothing for $who (${imported.outcome}).';
        return notifyListeners();
      }
      final listed = await on.agentSignIns();
      if (turn != _turn) return;
      importing = false;
      refusal = null;
      final its = listed.where((each) => each.agent == agent).firstOrNull;
      if (its == null) return _unsaid();
      _taken(its);
      if (its.signedIn) _confirm();
    } on Exception catch (failed) {
      if (turn != _turn) return;
      importing = false;
      _refused(failed, 'whether the sign-in of $who was imported');
    }
  }

  /// Waits on the sign-in that runs, until the machine answers how it ended: on a connection of its own.
  void _waitOn() {
    final on = _on;
    final agent = _agent;
    if (on == null || agent == null) return;
    final turn = _turn;
    SignInWaited? last;
    unawaited(_wait?.cancel());
    _waitedOn = container;
    _wait = on
        .agentSignInWait(agent)
        .listen(
          (reply) {
            if (turn == _turn) last = reply;
          },
          onError: (Object failed) {
            if (turn != _turn) return;
            _wait = null;
            _waitedOn = null;
            container = null;
            _attach = null;
            state = null;
            _refused(failed, 'how the sign-in of $who ended');
          },
          onDone: () {
            if (turn != _turn) return;
            _wait = null;
            _waitedOn = null;
            _waitEnded(last);
          },
          cancelOnError: true,
        );
    notifyListeners();
  }

  void _waitEnded(SignInWaited? reply) {
    container = null;
    _attach = null;
    if (reply == null) {
      state = null;
      words = '$machine did not say how the sign-in of $who ended, so nothing starts.';
      return notifyListeners();
    }
    if (reply.stored) {
      state = 'SIGNED_IN';
      words = 'Signed in to $who on $machine.';
      return _confirm();
    }
    // **Only stored reads as signed in**: every other end holds the start, its reason said; one the machine cannot
    // say starts only where its answer for the start says it can.
    state = switch (reply.reason) {
      'VAULT_LOCKED' || 'CANNOT_SAY' || 'NO_PROVIDER' => reply.reason,
      _ => 'NOT_SIGNED_IN',
    };
    const again = ' Sign in again to try once more.';
    words = switch (reply.reason) {
      'VAULT_LOCKED' => _vaultShut,
      'CANNOT_SAY' =>
        '$machine cannot say whether $who is signed in: its default provider cannot be used there. Work starts only '
            'where $machine says it can.',
      'NOTHING_TO_COLLECT' => 'The sign-in to $who on $machine ended with nothing to store.$again',
      'FAILED' => 'The sign-in to $who on $machine failed.$again',
      'NO_PROVIDER' =>
        '$machine has no provider to store the sign-in of $who under. Work starts only where $machine says it can.',
      'NONE_RUNNING' => 'No sign-in of $who runs on $machine, and its vault holds nothing for it.$again',
      'TIMED_OUT' => 'The sign-in to $who on $machine was not finished within 30 minutes.$again',
      'NOT_SIGNED_IN' || '' => 'The sign-in to $who on $machine ended without signing in.$again',
      final other => 'The sign-in to $who on $machine ended: $other.$again',
    };
    // Whether work can start is asked again, which alone decides for one the machine cannot say.
    if (state == 'CANNOT_SAY' || state == 'NO_PROVIDER') return _confirm();
    notifyListeners();
  }

  /// Signed in: held until whether work can start is asked again, since signed in alone never offers a start.
  void _confirm() {
    final signedIn = onSignedIn;
    if (signedIn == null) return notifyListeners();
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

  /// Says why the machine did not answer, in its words; the start stays held.
  void _refused(Object failed, String what) {
    words = switch (failed) {
      VarlinkDisconnected(:final message) => 'Lost contact with $machine: $message. Nothing starts until it answers.',
      FeatureNotSupported() => '$machine could not say $what: it needs a newer Porelo.',
      VarlinkException(:final parameters, :final simpleName) =>
        '$machine could not say $what: ${parameters['message'] ?? parameters['detail'] ?? simpleName}',
      _ => '$machine could not say $what: $failed',
    };
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
