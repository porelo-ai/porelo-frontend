import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing has been granted yet
Future<void> nothingHasBeenGrantedYet(WidgetTester tester) async {
  // Read off the socket rather than off the screen: what makes a preview a preview is that the
  // call carried `dryRun`, and a screen showing a preview while having written is exactly the
  // failure this guards.
  expect(World.backend.widenings, isNotEmpty);
  expect(
    World.backend.widenings.every((asked) => asked.preview),
    isTrue,
    reason: 'something was granted before it was agreed to',
  );
}
