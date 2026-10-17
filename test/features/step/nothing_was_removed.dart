import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing was removed
///
/// Read off the socket rather than off the screen: what makes a preview a preview is that the
/// call carried `dryRun`, and a screen showing a preview while having removed a project is
/// exactly the failure this guards.
Future<void> nothingWasRemoved(WidgetTester tester) async {
  expect(World.backend.deletions, isNotEmpty, reason: 'nothing was asked of the machine at all');
  expect(
    World.backend.deletions.every((asked) => asked.preview),
    isTrue,
    reason: 'something was removed before anybody agreed to it',
  );
}
