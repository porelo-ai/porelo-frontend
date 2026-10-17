import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: one agent is shadowed by another copy
Future<void> oneAgentIsShadowedByAnotherCopy(WidgetTester tester) async {
  World.backend.theAgentsItNeverUses = const <ShadowedAgent>[
    ShadowedAgent(
      path: '/usr/libexec/porelo/agents/an-agent',
      usedInstead: '/home/somebody/.local/share/porelo/agents/an-agent',
    ),
  ];
}
