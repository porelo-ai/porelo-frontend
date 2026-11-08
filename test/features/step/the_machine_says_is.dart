import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
///
/// The machine has sign-ins of its own; one that runs is in the login task `porelo-login-<agent>`.
Future<void> theMachineSaysIs(WidgetTester tester, String agent, String state) async {
  World.backend
    ..signsIn = true
    ..signInOf[agent] = AgentSignIn(
      agent: agent,
      provider: 'a-provider',
      state: state,
      loginTask: state == 'SIGNING_IN' ? 'porelo-login-$agent' : null,
    );
}
