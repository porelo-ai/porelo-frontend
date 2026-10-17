import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} cannot be seen
Future<void> theWorkCannotBeSeen(WidgetTester tester, String work) async {
  // The normal answer for a task with a terminal attached: its work goes to that terminal and not
  // to anything the daemon reads.
  World.theWorkIs(work, activity: 'UNKNOWN');
  await World.settle(tester);
}
