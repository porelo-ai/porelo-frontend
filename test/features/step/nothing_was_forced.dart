import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing was forced
Future<void> nothingWasForced(WidgetTester tester) async {
  expect(
    World.backend.deletions.every((asked) => !asked.force),
    isTrue,
    reason: 'a refusal was overridden without anybody saying so twice',
  );
}
