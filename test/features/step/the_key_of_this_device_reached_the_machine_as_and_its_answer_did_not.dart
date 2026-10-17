import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';

import '../support/world.dart';

/// Usage: the key of this device reached the machine as {'desk'} and its answer did not
Future<void> theKeyOfThisDeviceReachedTheMachineAsAndItsAnswerDidNot(
    WidgetTester tester, String name) async {
  // A key is kept before it is sent, so a lost answer leaves one with no slot beside it.
  const share = 'a share the machine already took';
  await World.keys.write(World.backend.nodeId, const DeviceKey(slot: '', share: share));
  World.backend.keyslotsHeld.add((
    slot: Keyslot(
      id: 'slot-${World.backend.keyslotsHeld.length}',
      name: name,
      storage: KeyslotStorage.userScoped,
      enrolled: '2026-09-18T08:00:00Z',
      lastUsed: '',
      self: false,
      recovery: false,
    ),
    share: share,
  ));
  await World.vault.devices.look(World.backend);
  await World.settle(tester);
}
