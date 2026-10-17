import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing has been stopped
Future<void> nothingHasBeenStopped(WidgetTester tester) async {
  // Read off the socket rather than off the screen: what makes a preview a preview is that the
  // call carried `dryRun`, and a screen showing a preview while having stopped a machine is
  // exactly the failure this guards.
  expect(World.backend.panics, isNotEmpty);
  expect(
    World.backend.panics.every((preview) => preview),
    isTrue,
    reason: 'something was stopped before anybody agreed to it',
  );
}
