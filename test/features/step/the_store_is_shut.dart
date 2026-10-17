import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store is shut
Future<void> theStoreIsShut(WidgetTester tester) async {
  // Shut and empty answer the same way about names, and must never be shown the same way.
  World.backend.theStoreIs = VaultState.from(const <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': true,
    'credentials': <Map<String, dynamic>>[],
    'readable': false,
  });
  // Shut after the title already asked, the way a person shuts it at the machine.
  await World.vault.look(World.backend);
  await World.settle(tester);
}
