import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: the planner was asked to {'resend'} the held save of {'cart-move'}
Future<void> thePlannerWasAskedToTheHeldSaveOf(WidgetTester tester, String what, String story) async {
  expect(World.planning.heldSaveCalls, ['$what ${heldSaveId(story)}']);
}
