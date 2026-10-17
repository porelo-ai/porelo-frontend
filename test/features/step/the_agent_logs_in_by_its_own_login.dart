import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} logs in by its own login
Future<void> theAgentLogsInByItsOwnLogin(WidgetTester tester, String name) async {
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
              // Named differently from what this end would spell, so a scenario can tell which ran.
              loginCommand: <String>['porelo', 'vault', 'login', '--agent', agent.name],
              loginDocumentation: 'https://docs.example.test/login',
            ),
  ];
}
