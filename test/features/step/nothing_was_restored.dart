import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing was restored
Future<void> nothingWasRestored(WidgetTester tester) async {
  expect(
    World.backend.restores.every((asked) => asked.preview),
    isTrue,
    reason: 'a mirror was written over before anybody agreed to it',
  );
}
