import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the vault holds no credential for what a run would use
Future<void> theVaultHoldsNoCredentialForWhatARunWouldUse(WidgetTester tester) async {
  // `credential` is the key that was actually looked for. An older vault answers under the
  // agent's own name, so naming the other would report a key missing from a vault that has it.
  World.backend.nextReadiness = const Readiness(
    ready: false,
    outcome: StartOutcome.credentialMissing,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: "the vault holds no credential for 'a-provider'",
  );
}
