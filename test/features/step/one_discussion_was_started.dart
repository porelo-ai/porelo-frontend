import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: one discussion was started
Future<void> oneDiscussionWasStarted(WidgetTester tester) async {
  expect(World.backend.discussed, hasLength(1), reason: 'one press, one discussion');
}
