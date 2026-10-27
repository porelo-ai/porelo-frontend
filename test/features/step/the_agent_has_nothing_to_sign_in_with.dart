import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent {'an-agent'} has nothing to sign in with
Future<void> theAgentHasNothingToSignInWith(WidgetTester tester, String agent) async {
  World.backend.readinessOf[agent] = Readiness(
    ready: false,
    outcome: StartOutcome.credentialMissing,
    agent: agent,
    provider: 'a-provider',
    credential: agent,
    detail: "the vault holds no credential for '$agent'",
  );
}
