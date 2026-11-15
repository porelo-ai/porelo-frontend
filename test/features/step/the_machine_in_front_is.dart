import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine in front is {name}
Future<void> theMachineInFrontIs(WidgetTester tester, String name) async {
  // A task opened on the board's machine, not the one it ran on, makes this fail.
  expect(World.machines.current.name, name);
}
