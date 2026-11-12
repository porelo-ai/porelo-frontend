import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the attached agent in {'porelo-checkout-shell'} is working
Future<void> theAttachedAgentInIsWorking(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'WORKING', mode: 'AGENT');
  await World.settle(tester);
}
