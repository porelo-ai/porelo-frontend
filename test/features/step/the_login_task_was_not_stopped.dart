import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the login task was not stopped
Future<void> theLoginTaskWasNotStopped(WidgetTester tester) async {
  expect(World.backend.stops, isEmpty, reason: 'leaving drops only the wait; the login task goes on');
}
