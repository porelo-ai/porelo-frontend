import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was told the person reaches it from another one
Future<void> theMachineWasToldThePersonReachesItFromAnotherOne(WidgetTester tester) async {
  expect(World.backend.signInStarts, isNotEmpty, reason: 'no sign-in was started');
  expect(World.backend.signInStarts.map((each) => each.remote), everyElement(isTrue));
}
