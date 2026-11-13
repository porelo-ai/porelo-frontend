import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the tasks the planning save stopped were stopped on this machine
Future<void> theTasksThePlanningSaveStoppedWereStoppedOnThisMachine(WidgetTester tester) async {
  final named = [
    for (final run in World.planning.stopped)
      for (final task in (run['tasks'] as List).cast<Map<String, dynamic>>()) task['containerId'] as String,
  ];
  expect(named, isNotEmpty, reason: 'the save stopped the run it warned of');
  expect(World.planning.moveCalls.single['confirm'], isTrue, reason: 'the save carries the confirmation');
  // Ending a task the save did not name, or leaving one it named running, makes this fail.
  expect(World.backend.stops, unorderedEquals(named));
}
