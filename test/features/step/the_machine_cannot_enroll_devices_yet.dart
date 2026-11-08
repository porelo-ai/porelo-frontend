import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/machine_tools.dart';

/// Usage: the machine cannot enroll devices yet
Future<void> theMachineCannotEnrollDevicesYet(WidgetTester tester) async {
  World.backend.keyslotsUnknown = true;
  final vault = await vaultOfCurrentMachine(tester);
  await vault.devices.look(World.backend);
  await World.settle(tester);
}
