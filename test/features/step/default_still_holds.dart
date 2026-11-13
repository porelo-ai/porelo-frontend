import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: default still holds {'foo-2'}
Future<void> defaultStillHolds(WidgetTester tester, String name) async {
  expect(World.backend.inDefault.where((each) => each.name == name), hasLength(1));
}
