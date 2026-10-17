import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: another device {'phone'} keeps its key {'APPLICATION_SCOPED'}
Future<void> anotherDeviceKeepsItsKey(WidgetTester tester, String name, String storage) async {
  World.backend.keyslotsHeld.add((
    slot: Keyslot(
      id: 'slot-${World.backend.keyslotsHeld.length}',
      name: name,
      storage: KeyslotStorage(storage),
      enrolled: '2026-09-10T09:00:00Z',
      lastUsed: '',
      self: false,
      recovery: false,
    ),
    share: 'a share held by $name',
  ));
}
