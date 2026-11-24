import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/world.dart';

/// Usage: the planner refuses to resend a save as no longer held
///
/// Another window sent it again first, so the planner answers `SaveNotHeld`, in words the screen does not show.
Future<void> thePlannerRefusesToResendASaveAsNoLongerHeld(WidgetTester tester) async {
  World.planning.resendRefusal = const PlanningRefusal('SaveNotHeld', {}, 'the group is not held');
}
