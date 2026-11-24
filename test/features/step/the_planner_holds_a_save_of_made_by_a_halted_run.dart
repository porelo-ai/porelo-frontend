import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: the planner holds a save of {'cart-move'} made by a halted run
///
/// A run's save the planner could not write: its run's Stop or Start decides it, so it is never sent again from here.
Future<void> thePlannerHoldsASaveOfMadeByAHaltedRun(WidgetTester tester, String story) async {
  World.planning.holdSave('checkout', heldSaveOf(story, run: true));
  await World.settle(tester);
}
