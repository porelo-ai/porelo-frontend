import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked to start {1} sign-ins
Future<void> theMachineWasAskedToStartSignins(WidgetTester tester, num count) async {
  expect(World.backend.signInStarts, hasLength(count), reason: 'never a second sign-in beside one that runs');
}
