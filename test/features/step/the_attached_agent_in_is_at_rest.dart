import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the attached agent in {'porelo-checkout-shell'} is at rest
Future<void> theAttachedAgentInIsAtRest(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'AT_REST', mode: 'AGENT');
  await World.settle(tester);
}
