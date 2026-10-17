import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';

import '../support/world.dart';

/// Usage: this device is enrolled on the machine
Future<void> thisDeviceIsEnrolledOnTheMachine(WidgetTester tester) async {
  const share = 'the share this device keeps';
  final id = 'slot-${World.backend.keyslotsHeld.length}';
  World.backend.keyslotsHeld.add((
    slot: Keyslot(
      id: id,
      name: 'laptop',
      storage: KeyslotStorage.userScoped,
      enrolled: '2026-09-18T08:00:00Z',
      lastUsed: '',
      self: false,
      recovery: false,
    ),
    share: share,
  ));
  await World.keys.write(World.backend.nodeId, DeviceKey(slot: id, share: share));
  await World.vault.devices.look(World.backend);
  await World.settle(tester);
}
