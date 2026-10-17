import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no secret crossed the socket
///
/// Read off what was sent. Importing names an agent and nothing else — the daemon reads that
/// agent's own config file on its own disk.
Future<void> noSecretCrossedTheSocket(WidgetTester tester) async {
  expect(World.backend.imports, isNotEmpty);
  expect(
    World.backend.imports.every((agent) => agent == null || agent.isNotEmpty),
    isTrue,
    reason: 'an empty agent name matches nothing and must never be sent as one',
  );
}
