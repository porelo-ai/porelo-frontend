import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine says starting {'porelo-checkout-shell'} needs the vault unlocked
Future<void> theMachineSaysStartingNeedsTheVaultUnlocked(WidgetTester tester, String work) async {
  World.theStartWouldBe(work, 'NEEDS_VAULT');
  await World.settle(tester);
}
