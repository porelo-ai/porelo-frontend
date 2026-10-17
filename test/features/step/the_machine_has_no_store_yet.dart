import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has no store yet
Future<void> theMachineHasNoStoreYet(WidgetTester tester) async {
  // What a fresh machine answers: no file, and readable and empty, because there is nothing to open.
  World.backend.theStoreIs = VaultState.from(const <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': false,
    'credentials': <Map<String, dynamic>>[],
    'readable': true,
  });
  await World.vault.look(World.backend);
  await World.settle(tester);
}
