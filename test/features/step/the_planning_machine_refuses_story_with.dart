import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planning machine refuses story {id} with {words}
Future<void> thePlanningMachineRefusesStoryWith(WidgetTester tester, String id, String words) async {
  World.planning.refusedStory = id;
  World.planning.refusalDetail = words;
}
