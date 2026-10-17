import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agent names no default provider
Future<void> theAgentNamesNoDefaultProvider(WidgetTester tester) async {
  // A provider, not a secret. Sending somebody to store one would be the wrong action entirely.
  World.backend.nextReadiness = const Readiness(
    ready: false,
    outcome: StartOutcome.noProviderChosen,
    agent: 'an-agent',
    provider: '',
    credential: '',
    detail: 'names no default provider, so one has to be chosen',
  );
}
