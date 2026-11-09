import 'package:porelo_frontend/client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planning machine refuses moves with {words}
Future<void> thePlanningMachineRefusesMovesWith(WidgetTester tester, String words) async {
  World.backend.planningMoveFailure = VarlinkException('org.fuin.porelo.Tasks1.WorkNotAllowed', {'detail': words});
}
