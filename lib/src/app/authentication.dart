import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Which providers this machine has, which of them work could start against, and where a
/// credential for each belongs.
///
/// **No secret passes through here, and that is settled rather than pending.** What this screen
/// shows for an unauthenticated provider is the command to run at the machine — and the person
/// reading it already holds an ssh connection there, because that is why this window can see the
/// socket at all. Importing is different and is offered: the daemon reads the agent's own config
/// file on its own disk, and only a name crosses.
class Authentication extends ChangeNotifier {
  /// What the machine said, or null before it has been asked.
  Providers? answer;

  /// What the last import did, or null.
  Imported? imported;

  /// Whether it is being asked right now.
  bool busy = false;

  /// Why it could not be read, in words.
  String? problem;

  /// Which question is outstanding, so a stale answer never lands on a newer one.
  int _asked = 0;

  /// Whether what the vault says can be believed.
  ///
  /// **`authenticated` is meaningless without this**, the same trap `Credentials` had: a locked
  /// store and an empty one answered alike until it was fixed.
  bool get readable => answer?.readable ?? false;

  /// The providers this machine has.
  List<Provider> get providers => answer?.providers ?? const <Provider>[];

  /// Reads what the machine has.
  Future<void> look(FleetBackend backend) async {
    final mine = ++_asked;
    busy = true;
    problem = null;
    // A fresh read is a fresh page: an earlier import's answer is not this one's.
    imported = null;
    importProblem = null;
    importedFor = null;
    notifyListeners();
    try {
      final said = await backend.providers();
      if (mine != _asked) return;
      answer = said;
    } on VarlinkException catch (refusal) {
      if (mine != _asked) return;
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (mine != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (mine != _asked) return;
      problem = '$ex';
    } finally {
      if (mine == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Imports a credential the agent already holds on that machine.
  ///
  /// [agent] omitted means *the only one installed*, which is **not** the same as an empty string:
  /// an empty name matches nothing, and the two are kept apart on the daemon's side too.
  Future<void> importFor(FleetBackend backend, {String? agent}) async {
    if (importing) return;
    importing = true;
    imported = null;
    importProblem = null;
    importedFor = agent;
    notifyListeners();
    try {
      imported = await backend.importCredential(agent: agent);
      // What is on screen has to be what is true: a credential that arrived changes which
      // providers are authenticated. A read begun before the import is no longer this one.
      if (imported?.stored ?? false) {
        final mine = ++_asked;
        try {
          final said = await backend.providers();
          if (mine == _asked) answer = said;
        } on Object catch (ex) {
          // The import stands; only the list did not read again.
          if (mine == _asked) problem = 'Imported, but the providers could not be read again: $ex';
        }
      }
      // A failed import is said where it was pressed; the providers it did not touch stay read.
    } on VarlinkException catch (refusal) {
      importProblem = 'The import was refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      importProblem = 'Lost contact with the machine during the import: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      importProblem = '$ex';
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  /// Whether an import runs, apart from a read of the providers.
  bool importing = false;

  /// The provider the last import was pressed for, null for the only agent installed.
  String? importedFor;

  /// Why the last import failed, said beside its button; null when it answered.
  String? importProblem;

  /// What the last import said, in one line: its answer or why it failed, empty before one.
  String get importSaid => importProblem ?? importWords;

  /// What the last import did, in one line.
  ///
  /// Three of these are not failures and must not read as one. **Nothing to import is the ordinary
  /// case** — the agent is installed and nobody has logged in with it there yet — and a shut store
  /// is not a missing credential.
  String get importWords {
    final said = imported;
    if (said == null) return '';
    return switch (said.outcome) {
      'IMPORTED' => 'Stored as ${said.name}: ${said.length} characters, from ${said.source}.',
      'NOTHING_TO_IMPORT' =>
        'That agent is installed and nobody has logged in with it on that machine yet, so there '
            'is nothing to import. Logging in there is the next step.',
      'VAULT_LOCKED' =>
        'The vault is shut, so nothing here can say whether it holds one. It is opened at the '
            'machine.',
      'NO_SUCH_AGENT' => 'No agent of that name is installed on that machine.',
      'NO_CONFIG_DIRECTORY' => 'That agent keeps its credentials somewhere this machine could not find.',
      'FAILED' => 'It could not be imported. ${said.detail}'.trim(),
      _ => '${said.outcome}. ${said.detail}'.trim(),
    };
  }

  /// Puts the result of an import away.
  void letItBe() {
    imported = null;
    importProblem = null;
    notifyListeners();
  }
}
