import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'other-agent'} runs through the provider {'b-provider'}
///
/// Asked whether work can start with that agent, the machine answers ready, through that provider.
Future<void> theAgentRunsThroughTheProvider(WidgetTester tester, String agent, String provider) async {
  World.backend.readinessOf[agent] = Readiness(
    ready: true,
    outcome: StartOutcome.ready,
    agent: agent,
    provider: provider,
    credential: provider,
    detail: '',
  );
}
