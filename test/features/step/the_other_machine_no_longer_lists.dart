import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the other machine no longer lists {name}
Future<void> theOtherMachineNoLongerLists(WidgetTester tester, String name) async {
  World.elsewhere.takesAway('porelo-checkout_$name');
  await World.settle(tester);
}
