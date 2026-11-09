import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked once which agents are signed in
Future<void> theMachineWasAskedOnceWhichAgentsAreSignedIn(WidgetTester tester) async {
  expect(World.backend.signInsAsked, 1, reason: 'one question for every agent to start');
}
