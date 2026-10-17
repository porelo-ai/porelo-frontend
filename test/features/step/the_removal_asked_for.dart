import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the removal asked for {'porelo-checkout-shell'}
Future<void> theRemovalAskedFor(WidgetTester tester, String task) async {
  expect(World.backend.removals, isNotEmpty);
  expect(World.backend.removals.last.task, task);
}
