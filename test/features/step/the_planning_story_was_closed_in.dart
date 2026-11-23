import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the planning story {id} was closed in {state}
Future<void> thePlanningStoryWasClosedIn(WidgetTester tester, String id, String state) async {
  // Only a person's move closes a story, and it stays closed until it is reopened: the board the planner serves.
  final story = planningMaps(World.planning.boards['checkout']!, 'stories').singleWhere((story) => story['id'] == id);
  expect(
    planningMaps(story, 'issues'),
    isEmpty,
    reason: 'a closed story with open issues is not what the planner serves',
  );
  story['state'] = state;
}
