import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/device_key.dart';

import '../support/world.dart';
import '../support/machine_tools.dart';

/// Usage: this device keeps a key the machine no longer has a slot for
Future<void> thisDeviceKeepsAKeyTheMachineNoLongerHasASlotFor(WidgetTester tester) async {
  // What a vault made again leaves behind: the node is the same, the slot this key opened is gone.
  await World.keys.write(World.backend.nodeId, const DeviceKey(slot: 'slot-from-the-old-vault', share: 'b2xk'));
  final vault = await vaultOfCurrentMachine(tester);
  await vault.devices.look(World.backend);
  await World.settle(tester);
}
