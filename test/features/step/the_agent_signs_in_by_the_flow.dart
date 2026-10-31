import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} signs in by the flow {'loopback'}
Future<void> theAgentSignsInByTheFlow(WidgetTester tester, String name, String flow) async {
  World.backend.theAgentsItHas = <Agent>[
    for (final agent in World.backend.theAgentsItHas)
      agent.name != name
          ? agent
          : Agent(
              name: agent.name,
              label: agent.label,
              binary: agent.binary,
              version: agent.version,
              from: agent.from,
              allowedDomains: agent.allowedDomains,
              refusedDomains: agent.refusedDomains,
              artifacts: agent.artifacts,
              commitsAs: agent.commitsAs,
              canLogIn: agent.canLogIn,
              loginArguments: agent.loginArguments,
              loginCommand: agent.loginCommand,
              loginDocumentation: agent.loginDocumentation,
              // Read the way the machine's reply is, so the scenario sees what the interface decodes.
              loginFlow: Agent.from(<String, dynamic>{'loginFlow': flow}).loginFlow,
            ),
  ];
}
