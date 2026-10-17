import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: nobody could look inside the work
///
/// Not the same as holding nothing: this is a task killed, rebooted, or stopped by a Porelo that
/// left no note.
Future<void> nobodyCouldLookInsideTheWork(WidgetTester tester) async {
  World.backend.theWorkItHolds = const HeldWork(readable: false, changedFiles: 0, unpushedCommits: 0);
}
