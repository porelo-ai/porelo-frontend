import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// What agents are installed on one machine.
///
/// An agent is installed separately from the thing that runs it, so *what is here* is a real
/// question with a real answer, and the answer is different on every machine. Nothing in this
/// interface names a specific agent: the list is discovered, always.
///
/// **The ones that failed to describe themselves are part of the answer.** An agent that cannot
/// say what it is is installed and unusable, and leaving it out would read as not installed —
/// which is the state somebody would not go looking for.
///
/// **`Agents` answers one entry per name.** They are held in a map keyed by name on the daemon
/// side, so two copies of one name never arrive here. Shadowing is resolved before anything is
/// listed — first location wins, most specific first — and the losers come back in their own
/// list, each naming the copy that runs instead.
class AgentInventory extends ChangeNotifier {
  /// What answered, in the order it was given.
  List<Agent> agents = const <Agent>[];

  /// Installed and unusable, by file name, with why.
  Map<String, String> failures = const <String, String>{};

  /// Installed and never started, because another copy wins.
  ///
  /// Not a state on an agent: a shadowed binary is resolved away before anything is listed, so it
  /// has no entry to mark. Each one names the copy that runs instead — *"not in use"* alone
  /// leaves somebody asking where to look.
  List<ShadowedAgent> shadowed = const <ShadowedAgent>[];

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Why it could not be read, in words. Null when nothing is wrong.
  String? problem;

  /// Whether anything has been asked yet.
  bool asked = false;

  /// Asks the machine what it has.
  Future<void> load(FleetBackend backend) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      final answered = await backend.agentsOn();
      agents = answered.agents;
      failures = answered.failures;
      shadowed = answered.shadowed;
      asked = true;
    } on VarlinkException catch (refusal) {
      problem = 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
