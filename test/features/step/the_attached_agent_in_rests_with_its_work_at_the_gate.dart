import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the attached agent in {'porelo-checkout-shell'} rests with its work at the gate
Future<void> theAttachedAgentInRestsWithItsWorkAtTheGate(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'AT_REST', mode: 'AGENT', waiting: 1);
  await World.settle(tester);
}
