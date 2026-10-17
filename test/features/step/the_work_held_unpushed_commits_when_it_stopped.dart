import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work held {4} unpushed commits when it stopped
Future<void> theWorkHeldUnpushedCommitsWhenItStopped(WidgetTester tester, int commits) async {
  World.backend.theWorkItHolds = HeldWork(
    readable: true,
    changedFiles: 0,
    unpushedCommits: commits,
    // Present, so the answer is historical — the workspace is inside a container that is down.
    asOf: DateTime.now().toUtc().subtract(const Duration(minutes: 12)),
  );
}
