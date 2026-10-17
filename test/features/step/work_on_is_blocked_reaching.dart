import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: work on {'elsewhere'} is blocked reaching {'api.example.test:443'}
Future<void> workOnIsBlockedReaching(WidgetTester tester, String machine, String where) async {
  // The other machine has one piece of work, and a question is always about work.
  expect(machine, 'elsewhere', reason: 'only elsewhere is a second machine here');
  World.elsewhere.asking.add(World.blocked(where, task: 'porelo-shared-shell'));
  await World.settle(tester);
}
