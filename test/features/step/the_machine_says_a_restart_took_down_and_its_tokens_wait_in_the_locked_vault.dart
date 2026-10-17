import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine says a restart took {'porelo-checkout-shell'} down and its tokens wait in the locked vault
Future<void> theMachineSaysARestartTookDownAndItsTokensWaitInTheLockedVault(WidgetTester tester, String work) async {
  // As Porelo 200 answered List for such a task on the VM.
  World.theStartWouldBe(work, 'NEEDS_VAULT', detail: 'the machine restarted; starting it brings it back whole');
  await World.settle(tester);
}
