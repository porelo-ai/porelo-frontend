import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'An Agent'} fetches nothing
Future<void> theAgentFetchesNothing(WidgetTester tester, String label) async {
  // A normal answer, not an empty one: an agent that writes its tool into the image pins a
  // version and has no digest to check.
  World.backend.theAgentsItHas = <Agent>[
    for (final agent in World.backend.theAgentsItHas)
      if (agent.label == label)
        Agent(
          name: agent.name,
          label: agent.label,
          binary: agent.binary,
          version: agent.version,
          from: agent.from,
          allowedDomains: agent.allowedDomains,
          refusedDomains: agent.refusedDomains,
        )
      else
        agent,
  ];
}
