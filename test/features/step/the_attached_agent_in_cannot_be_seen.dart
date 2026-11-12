import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the attached agent in {'porelo-checkout-shell'} cannot be seen
Future<void> theAttachedAgentInCannotBeSeen(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'UNKNOWN', mode: 'AGENT');
  await World.settle(tester);
}
