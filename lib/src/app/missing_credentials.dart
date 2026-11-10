import 'package:porelo_frontend/client.dart';

import 'connections.dart' show onTheMachine, quoteForAShell;
import 'machines.dart';

/// Whether this window runs a command on [machine] itself, over its own ssh to it.
///
/// **Only there, never on this computer**: a host's command for a missing credential makes it for the host's own
/// forge and keeps it in the person's vault there; run here it would reach another vault, or none.
bool reachesTheHostItself(Machine machine) =>
    machine.needsATunnel && machine.kind != 'wsl' && !machine.host.startsWith('-');

/// [missing]'s own command, run on [machine] in a terminal over ssh, in the account's login shell; null where this
/// window does not reach [machine] itself (see [reachesTheHostItself]) or [missing] names no command it would run.
List<String>? storedOnTheHost(Machine machine, MissingCredential missing) =>
    reachesTheHostItself(machine) ? onTheMachine(machine, missing.storeCommand, terminal: true) : null;

/// Words about a credential a machine lacks beside the agent, in the machine's own names; nothing derived that the
/// machine did not say.
extension MissingCredentialWords on MissingCredential {
  /// The forge the machine named, or empty where it named none in plain words.
  String get _forge => MissingCredential.plainWord(forge);

  /// What the vault lacks: a token for the forge the machine named, or else its vault key alone.
  String get _lacked => _forge.isNotEmpty
      ? 'token of yours for $_forge'
      : credential.isEmpty
      ? 'entry of yours it looks for'
      : '$credential of yours';

  /// What a press stores, named as the sentence about it names it.
  String get toStore => _forge.isNotEmpty
      ? 'your $_forge token'
      : credential.isEmpty
      ? 'it'
      : credential;

  /// Tells entries apart: what it is for, its vault key and its forge.
  (String, String, String) get identity => (purpose, credential, _forge);

  /// What [machine] lacks and what that costs a start there, which goes on all the same.
  String atTheStart(String machine) => switch (purpose) {
    'builds' =>
      "$machine's vault holds no $_lacked, so a task started there is not told its builds. "
          'Work starts all the same.',
    _ =>
      "$machine's vault holds no $_lacked, which ${purpose.isEmpty ? 'something' : purpose} needs there. "
          'Work starts all the same.',
  };

  /// What it takes once its command ran, in words; null for [done], which the place showing it does itself.
  String? afterStoring({required String done}) => afterStore == done
      ? null
      : switch (afterStore) {
          'ask-again' => 'Once it is stored, ask the machine again.',
          'restart' => 'Once it is stored, a task follows its builds only from its next start.',
          '' => 'The machine does not say what it takes once it is stored.',
          _ => 'Once it is stored, the machine says: $afterStore.',
        };

  /// The command as it is run, to copy into a terminal on the machine; null where it named none this window runs.
  String? get commandToCopy => storeCommand.isEmpty ? null : storeCommand.map(quoteForAShell).join(' ');

  /// Where this window does not run the command on [machine]: why, and where it is run instead.
  String notRunHere(String machine) => storeCommand.isEmpty
      ? "Store it on $machine with Porelo's own command for it, in a terminal there; the machine named none that "
            'can be shown here.'
      : 'Run this in a terminal on $machine itself: this window reaches $machine by no ssh of its own.';
}
