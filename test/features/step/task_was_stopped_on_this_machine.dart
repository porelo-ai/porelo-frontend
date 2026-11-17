import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: task {name} was stopped on this machine
Future<void> taskWasStoppedOnThisMachine(WidgetTester tester, String name) async {
  // A stop the planner recorded while the agent goes on running leaves this empty.
  expect(World.backend.stops, <String>['porelo-checkout_$name']);
}
