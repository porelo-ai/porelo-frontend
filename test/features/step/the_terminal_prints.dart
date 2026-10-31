import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal prints {'porelo: a loopback sign-in cannot run in a host account'}
Future<void> theTerminalPrints(WidgetTester tester, String words) async {
  World.terminals.last.prints('$words\r\n');
  await World.settle(tester);
}
