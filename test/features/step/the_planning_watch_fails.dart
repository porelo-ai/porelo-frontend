import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';

import '../support/world.dart';

/// Usage: the planning watch fails
Future<void> thePlanningWatchFails(WidgetTester tester) async {
  World.planning.fail(
    mockRefusal('org.fuin.porelo.Tasks1.WorkNotAllowed', {'detail': 'Planning store cannot be read'}),
  );
  await World.settle(tester);
}
