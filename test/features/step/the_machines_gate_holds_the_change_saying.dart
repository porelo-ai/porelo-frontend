import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine's gate holds the change {'plan'} saying {'Add the internal mirror'}
Future<void> theMachinesGateHoldsTheChangeSaying(WidgetTester tester, String name, String subject) async {
  World.backend.theGate = GateState.from(<String, dynamic>{
    'mode': 'gatekeeping',
    'pending': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': name,
        'commit': 'abc1234',
        'subject': subject,
        'waiting': '5 minutes',
        'at': '2026-09-30T11:00:00Z',
      },
    ],
  });
}
