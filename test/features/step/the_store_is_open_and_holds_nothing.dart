import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store is open and holds nothing
Future<void> theStoreIsOpenAndHoldsNothing(WidgetTester tester) async {
  World.backend.theStoreIs = VaultState.from(const <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': true,
    'credentials': <Map<String, dynamic>>[],
    'readable': true,
  });
}
