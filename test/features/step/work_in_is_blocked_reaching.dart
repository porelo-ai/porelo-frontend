import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: work in {'billing'} is blocked reaching {'api.example.test:443'}
Future<void> workInIsBlockedReaching(WidgetTester tester, String project, String where) async {
  // Turning one project off must not turn the others off with it.
  World.backend.asking.add(World.blocked(where, task: 'porelo-billing-shell'));
  await World.settle(tester);
}
