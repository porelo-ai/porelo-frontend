import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: another device {'old phone'} can open the store
Future<void> anotherDeviceCanOpenTheStore(WidgetTester tester, String name) async {
  World.backend.keyslotsHeld.add((
    slot: Keyslot(
      id: 'slot-${World.backend.keyslotsHeld.length}',
      name: name,
      storage: KeyslotStorage.applicationScoped,
      enrolled: '2026-09-10T09:00:00Z',
      lastUsed: '2026-09-17T18:00:00Z',
      self: false,
      recovery: false,
    ),
    share: 'a share held on another device',
  ));
}
