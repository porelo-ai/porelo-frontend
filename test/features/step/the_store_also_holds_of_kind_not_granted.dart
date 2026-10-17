import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the store also holds {'forge'} of kind {'oauth-code'}, not granted
Future<void> theStoreAlsoHoldsOfKindNotGranted(WidgetTester tester, String name, String kind) async {
  final store = World.backend.theStoreIs;
  World.backend.theStoreIs = VaultState(
    vault: store.vault,
    exists: store.exists,
    credentials: <Credential>[...store.credentials, Credential(name: name, type: kind, characters: 0)],
    readable: store.readable,
  );
}
