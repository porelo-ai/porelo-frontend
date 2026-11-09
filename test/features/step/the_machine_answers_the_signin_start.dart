import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers the sign-in start
Future<void> theMachineAnswersTheSigninStart(WidgetTester tester) async {
  final held = World.backend.signInStartHeld;
  expect(held, isNotNull, reason: 'no sign-in start was held back');
  World.backend.signInStartHeld = null;
  held!.complete();
  await World.settle(tester);
}
