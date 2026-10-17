import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';
import 'i_show_the_vault.dart';

/// Usage: I ask about the store twice
Future<void> iAskAboutTheStoreTwice(WidgetTester tester) async {
  // Two parts of the interface asking at once. The slow one was asked first and answers last, so
  // an implementation that simply took whatever arrived would leave the older answer on screen.
  await iShowTheVault(tester);
  World.backend.credentialsTake = Duration.zero;
  World.backend.theStoreIs = VaultState.from(const <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': true,
    'credentials': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'the-newer-answer', 'type': 'api-key', 'characters': 12},
    ],
    'readable': true,
  });
  await World.vault.look(World.backend);
  await World.settle(tester);
  // Long enough for the first, slower answer to arrive if anything still wanted it.
  await tester.pump(const Duration(milliseconds: 400));
  await World.settle(tester);
}
