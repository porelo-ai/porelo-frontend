import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked once which agents are signed in
Future<void> theMachineWasAskedOnceWhichAgentsAreSignedIn(WidgetTester tester) async {
  expect(World.backend.signInsAsked, hasLength(1), reason: 'one question for every agent to start');
  // Each agent once, however many repositories name it.
  expect(World.backend.signInsAsked.single, hasLength(World.backend.signInsAsked.single!.toSet().length));
}
