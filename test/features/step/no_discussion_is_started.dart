import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no discussion is started
Future<void> noDiscussionIsStarted(WidgetTester tester) async {
  expect(World.backend.discussed, isEmpty);
}
