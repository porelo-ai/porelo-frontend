import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine can import the sign-in it found with {'porelo vault import an-agent'}
Future<void> theMachineCanImportTheSigninItFoundWith(WidgetTester tester, String command) async {
  World.backend.nextReadiness = Readiness(
    ready: false,
    outcome: StartOutcome.credentialMissing,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: '',
    agentSource: 'SIGNED_IN',
    agentFoundIn: '/home/person/.an-agent/credentials',
    importCommand: command.split(' '),
  );
}
