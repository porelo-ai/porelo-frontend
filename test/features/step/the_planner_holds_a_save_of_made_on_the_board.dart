import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: the planner holds a save of {'ST293'} made on the board
///
/// The planner could not write a move of the story made in a window, and keeps it to be sent again.
Future<void> thePlannerHoldsASaveOfMadeOnTheBoard(WidgetTester tester, String story) async {
  World.planning.holdSave('checkout', heldSaveOf(story, run: false));
  await World.settle(tester);
}
