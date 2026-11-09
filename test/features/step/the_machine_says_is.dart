import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
Future<void> theMachineSaysIs(WidgetTester tester, String agent, String state) async {
  World.backend
    ..signsIn = true
    ..signInOf[agent] = AgentSignIn(agent: agent, state: state);
}
