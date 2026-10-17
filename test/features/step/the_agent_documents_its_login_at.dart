import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} documents its login at {'http://[not an address'}
Future<void> theAgentDocumentsItsLoginAt(WidgetTester tester, String name, String page) async {
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
              canLogIn: true,
              loginCommand: <String>['porelo', 'vault', 'login', '--agent', agent.name],
              loginDocumentation: page,
            ),
  ];
}
