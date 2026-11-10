import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningUnsupported;

import '../support/world.dart';

/// Usage: the machine has no planning
Future<void> theMachineHasNoPlanning(WidgetTester tester) async {
  World.planning.unsupported = true;
  World.planning.fail(const PlanningUnsupported('this backend has no planning'));
  await World.settle(tester);
}
