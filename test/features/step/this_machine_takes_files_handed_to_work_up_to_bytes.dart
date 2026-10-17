import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: this machine takes files handed to work up to {8388608} bytes
Future<void> thisMachineTakesFilesHandedToWorkUpToBytes(WidgetTester tester, num limit) async {
  // What a machine with hand-in lists for every task: its run, its limit, and what it was handed.
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      FakeBackend.withHandIn(task, files: const <HandedFile>[], limit: limit.toInt(), run: '${task.name}-run-1'),
  ]);
}
