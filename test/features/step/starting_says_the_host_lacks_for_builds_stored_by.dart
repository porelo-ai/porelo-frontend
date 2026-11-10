import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting says the host lacks {'host-builds'} for builds, stored by {'porelo host forge-token'}
///
/// As a host answers it: ready, with the person's forge entry missing beside the agent.
Future<void> startingSaysTheHostLacksForBuildsStoredBy(WidgetTester tester, String credential, String command) async {
  World.backend.nextReadiness = Readiness(
    ready: true,
    outcome: StartOutcome.ready,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: '',
    missing: <MissingCredential>[
      MissingCredential(
        purpose: 'builds',
        credential: credential,
        storeCommand: command.split(' '),
        afterStore: 'ask-again',
      ),
    ],
  );
}
