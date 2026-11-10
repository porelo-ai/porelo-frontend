import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';

import '../support/world.dart';

/// Usage: the planning save refuses {name} for story {id} with {detail}
Future<void> thePlanningSaveRefusesForStoryWith(WidgetTester tester, String name, String id, String detail) async {
  World.planning.refusedStory = null;
  World.planning.moveFailure = mockRefusal('org.fuin.porelo.Tasks1.$name', {'story': id, 'detail': detail});
}
