import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine has answered
Future<void> theMachineHasAnswered(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  // What is read after this answers at once, so a scenario holds back only what it opened while slow.
  World.backend.readsTake = Duration.zero;
  await World.settle(tester);
}
