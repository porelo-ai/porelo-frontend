import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the discussion's Start because {'other-agent'} is not signed in
Future<void> theMachineRefusesTheDiscussionsStartBecauseIsNotSignedIn(WidgetTester tester, String agent) async {
  // As Porelo refuses: by name, with the agent, before anything is made; and its sign-ins say the same.
  World.backend
    ..signsIn = true
    ..signInOf[agent] = AgentSignIn(agent: agent, state: 'NOT_SIGNED_IN')
    ..discussionFails = VarlinkException('org.fuin.porelo.Tasks1.SignInNeeded', <String, dynamic>{'agent': agent});
}
