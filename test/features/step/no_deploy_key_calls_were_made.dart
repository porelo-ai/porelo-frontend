import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no deploy key calls were made
Future<void> noDeployKeyCallsWereMade(WidgetTester tester) async {
  // Harm: separate repository keys grant access outside the person's vault token.
  expect(World.backend.deployKeysMade, isEmpty, reason: 'the daemon must never be asked for a deploy key');
  expect(
    World.forge.keyCalls,
    isEmpty,
    reason: 'the forge must never be asked to make, list, check or remove a deploy key',
  );
}
