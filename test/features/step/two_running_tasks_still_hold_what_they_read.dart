import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: two running tasks still hold what they read
Future<void> twoRunningTasksStillHoldWhatTheyRead(WidgetTester tester) async {
  // A running task's proxy read the secret when it started and holds it where locking cannot
  // reach. Saying the store is shut without this claims more than happened.
  World.backend.nextLock = const Locked(keyring: true, wasCached: true, holding: 2);
}
