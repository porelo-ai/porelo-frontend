import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the agent of {'porelo-checkout-shell'} finished, with its work waiting at the gate
Future<void> theAgentOfFinishedWithItsWorkWaitingAtTheGate(WidgetTester tester, String work) async {
  World.theWorkIs(
    work,
    activity: 'ENDED',
    agentEnded: <String, dynamic>{
      'at': '2026-10-03T12:57:30Z',
      'finished': true,
      'error': '',
      'source': '',
      'unpushed': 0,
    },
    waiting: 1,
  );
  await World.settle(tester);
}
