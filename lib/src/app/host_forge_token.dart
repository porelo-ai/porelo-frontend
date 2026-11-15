import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'connections.dart' show onTheMachine;
import 'machines.dart';
import 'missing_credentials.dart' show reachesTheHostItself;

/// Runs a line a machine named and answers its exit code and its last line of words; see
/// `MachineSetup.runOnTheMachine`.
typedef RunOnTheMachine = Future<({int code, String said})> Function(List<String> command);

/// The person's forge token stored on a host by the machine's own command, which mints it there and writes it into
/// the person's host vault: the token passes between the host's helper and its vault alone, never through here.
///
/// **One run per machine at a time**, since each run mints a new token and revokes the one before; a press while one
/// runs joins it. The first missing token a machine names in this window's run is stored by itself, once.
class HostForgeTokens extends ChangeNotifier {
  /// Stores through the given run; [onStored] is told of each machine a run stored the token on.
  HostForgeTokens(this._run, {this.onStored});

  final RunOnTheMachine _run;

  /// Told of each machine a run stored the token on, so what it refused is asked for again.
  final void Function(Machine machine)? onStored;
  final _running = <String, Future<String?>>{};
  final _byItself = <String>{};
  final _failed = <String, String>{};

  /// Whether a run stores the token on [machine] now.
  bool running(String machine) => _running.containsKey(machine);

  /// Why the last run on [machine] stored nothing, or null.
  String? failed(String machine) => _failed[machine];

  /// The command that stores [missing] on [machine], as the machine named it, over the card's own ssh login; null
  /// where this window does not reach [machine] itself or the machine named no command it can run.
  static List<String>? commandFor(Machine machine, MissingHostForgeToken missing) =>
      missing.storeCommand.isEmpty || machine.hostCard == null || !reachesTheHostItself(machine)
      ? null
      : onTheMachine(machine, missing.storeCommand, terminal: false);

  /// Stores [missing] on [machine]: null once stored, or why not in the command's own words.
  Future<String?> store(Machine machine, MissingHostForgeToken missing) {
    final key = machine.name;
    if (_running[key] case final joined?) return joined;
    final command = commandFor(machine, missing);
    if (command == null) {
      return Future.value(
        missing.storeCommand.isEmpty
            ? '${machine.name} named no command for it that can be run from here, so nothing is stored there.'
            : "This window does not reach ${machine.name}'s own login, so it stores nothing there.",
      );
    }
    final run = _store(machine, command);
    _running[key] = run;
    _notify();
    return run;
  }

  Future<String?> _store(Machine machine, List<String> command) async {
    final key = machine.name;
    String? why;
    try {
      final ran = await _run(command);
      why = ran.code == 0
          ? null
          : ran.said.isEmpty
          ? 'Storing the forge token ended with exit code ${ran.code}.'
          : ran.said;
    } on Exception catch (error) {
      why = 'Storing the forge token could not be run: $error';
    }
    _running.remove(key);
    if (why == null) {
      _failed.remove(key);
    } else {
      _failed[key] = why;
    }
    _notify();
    if (why == null && !_disposed) onStored?.call(machine);
    return why;
  }

  /// Stores [missing] on [machine] by itself, the first time in this window's run that [machine] names it.
  void heard(Machine machine, MissingHostForgeToken missing) {
    if (_byItself.add(machine.name)) unawaited(store(machine, missing));
  }

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
