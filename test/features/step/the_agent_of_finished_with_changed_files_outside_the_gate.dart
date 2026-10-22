import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the agent of {'porelo-checkout-shell'} finished with {1} changed files outside the gate
Future<void> theAgentOfFinishedWithChangedFilesOutsideTheGate(WidgetTester tester, String work, int count) async {
  World.theWorkIs(
    work,
    activity: 'ENDED',
    agentEnded: <String, dynamic>{
      'at': '2026-10-03T12:57:30Z',
      'finished': true,
      'error': '',
      'source': '',
      'unpushed': count,
    },
    waiting: 0,
  );
  await World.settle(tester);
}
