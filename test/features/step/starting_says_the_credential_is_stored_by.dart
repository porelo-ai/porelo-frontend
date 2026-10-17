import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting says the credential is stored by {'porelo vault put a-provider'}
Future<void> startingSaysTheCredentialIsStoredBy(WidgetTester tester, String command) async {
  World.backend.nextReadiness = Readiness(
    ready: false,
    outcome: StartOutcome.credentialMissing,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: "the vault holds no credential for 'a-provider'",
    storeCommand: command.split(' '),
  );
}
