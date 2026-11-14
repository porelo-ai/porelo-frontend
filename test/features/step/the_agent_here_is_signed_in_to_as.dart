import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} here is signed in to {'other-provider'} as {'oauth'}
Future<void> theAgentHereIsSignedInToAs(WidgetTester tester, String agent, String provider, String kind) async {
  World.here.theSignInsItsAgentsHold = <ImportableCredential>[
    ...World.here.theSignInsItsAgentsHold,
    ImportableCredential(agent: agent, provider: provider, kind: kind),
  ];
}
