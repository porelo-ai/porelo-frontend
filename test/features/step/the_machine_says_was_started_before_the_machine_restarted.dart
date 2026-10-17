import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine says {'porelo-checkout-shell'} was started before the machine restarted
Future<void> theMachineSaysWasStartedBeforeTheMachineRestarted(WidgetTester tester, String work) async {
  // The detail as Porelo measured it on the Ubuntu VM, for this task.
  World.theStartWouldBe(
    work,
    'PREDATES_RESTART',
    detail:
        "started before this machine restarted; copy the workspace out with 'podman cp "
        "$work:/workspace ./recovered', then 'porelo task remove $work --force'",
  );
  await World.settle(tester);
}
