import 'package:porelo_frontend/client.dart';

import 'connections.dart' show onTheMachine, quoteForAShell;
import 'machines.dart';

/// Whether this window runs a command on [machine] itself, over its own ssh to it.
///
/// **Only there, never on this computer**: a host's command for a missing credential makes it for the host's own
/// forge and keeps it in the person's vault there; run here it would reach another vault, or none.
bool reachesTheHostItself(Machine machine) => machine.needsATunnel && machine.kind != 'wsl';

/// [missing]'s own command, run on [machine] in a terminal over ssh, in the account's login shell; null where this
/// window does not reach [machine] itself (see [reachesTheHostItself]) or [missing] names no command it would run.
List<String>? storedOnTheHost(Machine machine, MissingCredential missing) =>
    reachesTheHostItself(machine) ? onTheMachine(machine, missing.storeCommand, terminal: true) : null;

/// Words about a credential a machine lacks beside the agent, in the machine's own names; nothing derived that the
/// machine did not say.
extension MissingCredentialWords on MissingCredential {
  /// The vault key, or words for it where the machine named none.
  String get _key => credential.isEmpty ? 'the entry it looks for' : credential;

  /// What [machine] lacks and what that costs a start there, which goes on all the same.
  String atTheStart(String machine) => switch (purpose) {
    'builds' =>
      "$machine's vault holds no $_key of yours, so a task started there is not told its builds. "
          'Work starts all the same.',
    _ =>
      "$machine's vault holds no $_key of yours, which ${purpose.isEmpty ? 'something' : purpose} needs there. "
          'Work starts all the same.',
  };

  /// What it takes once its command ran, where the machine says something this window does not do itself; null
  /// for `ask-again` and `restart`, which it does or says.
  String? get thenUnknown => switch (afterStore) {
    'ask-again' || 'restart' => null,
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
