import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was asked twice whether it can run anything
///
/// Read off the socket. It runs external programs on the machine, so *"asked again"* has to mean
/// asked again rather than a screen redrawn from what it remembered.
Future<void> theMachineWasAskedTwiceWhetherItCanRunAnything(WidgetTester tester) async {
  expect(World.backend.healthAsked, 2);
}
