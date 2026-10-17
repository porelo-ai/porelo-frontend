import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: Porelo was not started
Future<void> poreloWasNotStarted(WidgetTester tester) async {
  expect(World.setup.asUserRan, isEmpty);
}
