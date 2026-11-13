import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';

import '../support/world.dart';

/// Usage: the planning save times out
///
/// The window stops waiting while the planner may still land the save.
Future<void> thePlanningSaveTimesOut(WidgetTester tester) async {
  World.planning.moveFailure = mockRefusal('TimedOut', const {});
}
