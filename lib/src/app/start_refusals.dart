import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'agent_sign_in.dart';
import 'fleet_backend.dart';

/// Start refused because the agent's model credential is missing on the machine; nothing was made. Carries what to
/// call the agent where the window knows it, so every path that says it names the agent alike.
class SignInNeeded implements Exception {
  /// Constructor taking the agent as the machine named it, the sign-in that runs there (`""` while one is being
  /// prepared, null where none runs), and what to call the agent.
  const SignInNeeded(this.agent, {this.running, this.label = ''});

  /// The agent, as the machine named it.
  final String agent;

  /// The container of this agent's sign-in that runs on the machine, `""` while it is prepared; null where none runs.
  final String? running;

  /// What to call the agent for a person, as the machine's `Agents` answer labels it; empty where it is not known.
  final String label;

  /// What to call the agent for a person.
  String get who => label.isNotEmpty ? label : (agent.isEmpty ? 'The agent' : agent);

  /// The same refusal, its agent called [label] where that says more than what it has.
  SignInNeeded labelled(String label) =>
      label.isEmpty || this.label.isNotEmpty ? this : SignInNeeded(agent, running: running, label: label);

  @override
  String toString() => startRefusalWords(this, machine: 'the machine');
}

/// One of `Start`'s named refusals as the exception that says it in words, or [error] as it came: the typed form is
/// what every start path receives from the machine, so each says it alike.
Object startRefusalSaid(Object error) => switch (error) {
  VarlinkException(simpleName: 'NoSuchDestination') => NoSuchDestination('${error.parameters['name'] ?? ''}'),
  VarlinkException(simpleName: 'EarlierWorkWaits') => EarlierWorkWaits(
    '${error.parameters['task'] ?? ''}',
    commit: '${error.parameters['commit'] ?? ''}',
    subject: '${error.parameters['subject'] ?? ''}',
  ),
  VarlinkException(simpleName: 'UpstreamUnreadable') => UpstreamUnreadable(
    '${error.parameters['cause'] ?? ''}',
    detail: '${error.parameters['detail'] ?? ''}',
    fix: '${error.parameters['fix'] ?? ''}',
  ),
  VarlinkException(simpleName: 'SignInNeeded') => SignInNeeded(
    '${error.parameters['agent'] ?? ''}',
    running: switch (error.parameters['running']) {
      final String running => running,
      _ => null,
    },
  ),
  _ => error,
};

/// What a refused start on [machine] says to a person, whichever way it was refused: each of `Start`'s refusals in
/// its own words, any other error of the machine by what it says, **never by the wire's type name alone**. Also safe
/// for an operation that is no start: the refusals only `Start` answers are the only ones worded as a start's.
String startRefusalWords(Object error, {required String machine}) {
  final said = startRefusalSaid(error);
  String text(String key) => switch (said) {
    VarlinkException(:final parameters) when parameters[key] is String => (parameters[key] as String).trim(),
    _ => '',
  };
  String sentence(String words) => words.isEmpty || '.!?'.contains(words[words.length - 1]) ? words : '$words.';
  return switch (said) {
    SignInNeeded(:final who, running: null) =>
      '$who is not signed in on $machine, so nothing was started. Sign it in there, then start again.',
    SignInNeeded(:final who) =>
      '$who is not signed in on $machine, so nothing was started. A sign-in to it already runs there: finish it, '
          'then start again.',
    VarlinkException(simpleName: 'VaultLocked') =>
      'The vault on $machine is locked, so nothing was done. Unlock it, then try again.',
    VarlinkException(simpleName: 'FirstStartRefused') => switch ((text('detail'), text('reason'))) {
      (final detail, _) when detail.isNotEmpty =>
        '$machine did not take the yes to the first start: ${sentence(detail)}',
      (_, final reason) => '$machine did not take the yes to the first start${reason.isEmpty ? '' : ' ($reason)'}.',
    },
    VarlinkException(simpleName: 'UnknownHostKey') =>
      '$machine has never met ${text('host').isEmpty ? 'the repository\'s host' : text('host')}, so nothing was '
          'started.${text('detail').isEmpty ? '' : ' ${sentence(text('detail'))}'}',
    VarlinkException(simpleName: 'BranchTaken') =>
      '${_task(text('task'))} was not started: its branch${text('branch').isEmpty ? '' : ' ${text('branch')}'} is '
          'taken.${text('detail').isEmpty ? '' : ' ${sentence(text('detail'))}'} Name another branch.',
    VarlinkException(simpleName: 'ContainerNameTaken') =>
      '${_task(text('task'))} was not started: its container ${text('container')} is held by '
          '${text('ownerTask').isEmpty ? 'something $machine cannot name' : 'the task ${text('ownerTask')}${text('ownerProject').isEmpty ? '' : ' of ${text('ownerProject')}'}'}. '
          'Choose another task name.',
    VarlinkException(simpleName: 'AlreadyStarting') =>
      '${_task(text('task'))} is being started on $machine already; nothing more was started.',
    VarlinkException(simpleName: 'MadeWithAnother') =>
      '${_task(text('task'))} was made with ${text('agent').isEmpty ? 'another agent' : text('agent')}'
          '${text('model').isEmpty ? '' : ' (${text('model')})'} and starts again only with it; nothing was started.',
    VarlinkException(simpleName: 'NoSuchTask') =>
      '$machine has no task${text('task').isEmpty ? '' : ' ${text('task')}'}.',
    VarlinkException(isMethodNotFound: true) => '$machine does not offer this; it needs a newer Porelo.',
    VarlinkException(:final simpleName, :final parameters) => switch ([
      text('detail'),
      text('message'),
      text('reason'),
    ].where((each) => each.isNotEmpty).firstOrNull) {
      final words? => '$machine refused: ${sentence(words)}',
      null =>
        '$machine refused ($simpleName'
            // The keys alone: a value the machine sent may be anything, a secret among them, and is never shown.
            '${parameters.isEmpty ? '' : ': ${parameters.keys.join(', ')}'}).',
    },
    _ => '$said',
  };
}

/// Whether [error] is a refusal Start answered, named or typed, rather than a fault on the way to the machine.
bool isStartRefusal(Object error) =>
    error is VarlinkException ||
    error is SignInNeeded ||
    error is NoSuchDestination ||
    error is EarlierWorkWaits ||
    error is UpstreamUnreadable ||
    error is StartRefused;

String _task(String task) => task.isEmpty ? 'The task' : task;

/// The sign-ins a start refused for, one per agent and machine, each offered under *Needs you* until the machine says
/// its agent is signed in there.
class SignInsNeeded extends ChangeNotifier {
  final _needed = <(String, String), SigningIn>{};

  /// Each sign-in still needed, in the order the starts were refused.
  List<SigningIn> get all => List.unmodifiable(_needed.values);

  /// Keeps the sign-in of [agent] on [machine], made by [make] where none is kept yet: a start refused again for it
  /// adds no second. Answers whether its row stands now, so nothing says it is offered where it is not.
  bool need(String machine, String agent, SigningIn Function() make) {
    if (_needed.containsKey((machine, agent))) return true;
    final signingIn = make();
    _needed[(machine, agent)] = signingIn;
    void follow() {
      if (!signingIn.signedIn || !identical(_needed[(machine, agent)], signingIn)) return;
      signingIn.removeListener(follow);
      _drop((machine, agent));
    }

    signingIn.addListener(follow);
    notifyListeners();
    follow();
    return identical(_needed[(machine, agent)], signingIn);
  }

  /// Drops every sign-in kept for a machine [watched] no longer says is watched; a sign-in that runs goes on there.
  void keepOnly(bool Function(String machine) watched) {
    final gone = [
      for (final key in _needed.keys)
        if (!watched(key.$1)) key,
    ];
    for (final key in gone) {
      _drop(key);
    }
  }

  void _drop((String, String) key) {
    final signingIn = _needed.remove(key);
    if (signingIn == null) return;
    // Left, not disposed: its row is still drawn as resolved, and a sign-in that runs goes on on the machine.
    signingIn.leave();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final signingIn in _needed.values) {
      signingIn
        ..leave()
        ..dispose();
    }
    _needed.clear();
    super.dispose();
  }
}
