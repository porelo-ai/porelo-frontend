import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the agent of {'porelo-checkout-shell'} ended with the provider's {402} {'This request requires more credits'}
///
/// A run: OpenRouter refused the first request, and the agent ended.
/// The container stays up; the machine says the agent ended, and how.
Future<void> theAgentOfEndedWithTheProviders(WidgetTester tester, String work, int status, String error) async {
  World.theWorkIs(
    work,
    activity: 'ENDED',
    agentEnded: <String, dynamic>{
      'at': '2026-10-03T12:57:30Z',
      'finished': false,
      'error': error,
      'source': 'provider',
      'status': status,
      'unpushed': 0,
    },
  );
  await World.settle(tester);
}
