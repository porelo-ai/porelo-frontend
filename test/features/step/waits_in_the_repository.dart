import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: {'Retry a declined card once'} waits in the repository {'payments-api'}
Future<void> waitsInTheRepository(WidgetTester tester, String subject, String repository) async {
  World.backend.theGatesIn[repository] = GateState.from(<String, dynamic>{
    'mirror': '/srv/checkout/.porelo/repositories/$repository/mirror',
    'mode': 'gatekeeping',
    'seededFrom': '',
    'pending': <Map<String, dynamic>>[
      <String, dynamic>{
        // The same ref name as the one waiting in the project's own repository, on purpose: two
        // repositories can each hold a `migrate`, and they are two pushes, not one.
        'name': 'migrate',
        'commit': 'b41e07c',
        'subject': subject,
        'waiting': '2 minutes',
        'at': '2026-09-07T14:14:00Z',
      },
    ],
  });
}
