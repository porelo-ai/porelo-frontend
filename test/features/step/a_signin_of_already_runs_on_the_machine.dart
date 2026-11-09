import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a sign-in of {'an-agent'} already runs on the machine
Future<void> aSigninOfAlreadyRunsOnTheMachine(WidgetTester tester, String agent) async {
  World.backend
    ..signsIn = true
    ..signInOf[agent] = AgentSignIn(agent: agent, state: 'NOT_SIGNED_IN', running: 'porelo-login-$agent');
}
