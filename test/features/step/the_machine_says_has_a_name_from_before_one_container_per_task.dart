import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine says {'porelo-checkout-shell'} has a name from before one container per task
Future<void> theMachineSaysHasANameFromBeforeOneContainerPerTask(WidgetTester tester, String work) async {
  World.theStartWouldBe(work, 'SUPERSEDED_NAME', detail: 'porelo-checkout-shell');
  await World.settle(tester);
}
