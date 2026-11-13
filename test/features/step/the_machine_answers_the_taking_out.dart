import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers the taking out
Future<void> theMachineAnswersTheTakingOut(WidgetTester tester) async {
  World.backend.leaveHeld?.complete();
  World.backend.leaveHeld = null;
  await World.settle(tester);
}
