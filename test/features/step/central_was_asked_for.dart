import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: central was asked for {'payments-api'}
Future<void> centralWasAskedFor(WidgetTester tester, String repositories) async {
  expect(World.backend.centralPushes, hasLength(1));
  expect(World.backend.centralPushes.single.project, 'checkout');
  expect(World.backend.centralPushes.single.repositories, repositories.split(', '));
}
