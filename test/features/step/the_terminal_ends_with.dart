import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the terminal ends with {0}
Future<void> theTerminalEndsWith(WidgetTester tester, int code) async {
  // `porelo vault init` that ends well has made the vault: the daemon then lists its passphrase.
  if (code == 0 &&
      World.terminals.last.command.join(' ').contains('vault init') &&
      World.backend.keyslotsHeld.isEmpty) {
    World.backend.keyslotsHeld.add((
      slot: const Keyslot(
        id: 'slot-0',
        name: 'recovery passphrase',
        storage: KeyslotStorage(''),
        enrolled: '2026-10-02T10:00:00Z',
        lastUsed: '',
        self: false,
        recovery: true,
      ),
      share: '',
    ));
  }
  World.terminals.last.endsWith(code);
  await World.settle(tester);
}
