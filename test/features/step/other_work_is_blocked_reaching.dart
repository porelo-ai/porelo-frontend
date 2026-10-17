import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: other work is blocked reaching {'files.example.test:22'}
Future<void> otherWorkIsBlockedReaching(WidgetTester tester, String where) async {
  // A different task: one subscription covers every task, including ones started later.
  World.backend.asking.add(World.blocked(where, task: 'porelo-billing-shell'));
  await World.settle(tester);
}
