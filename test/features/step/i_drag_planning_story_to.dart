import 'package:flutter_test/flutter_test.dart';

import 'i_hold_planning_story_over.dart';
import 'i_drop_the_planning_story.dart';

/// Usage: I drag planning story {id} to {state}
Future<void> iDragPlanningStoryTo(WidgetTester tester, String id, String state) async {
  await iHoldPlanningStoryOver(tester, id, state);
  await iDropThePlanningStory(tester);
}
