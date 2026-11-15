import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the start of story work because {'codex'} is not signed in
Future<void> theMachineRefusesTheStartOfStoryWorkBecauseIsNotSignedIn(WidgetTester tester, String agent) async {
  // As Porelo refuses: by name, with the agent, once it prepared the task; and its sign-ins say the same.
  World.backend
    ..signsIn = true
    ..signInOf[agent] = AgentSignIn(agent: agent, state: 'NOT_SIGNED_IN')
    ..orderedFails = VarlinkException('org.fuin.porelo.Tasks1.SignInNeeded', <String, dynamic>{'agent': agent});
}
