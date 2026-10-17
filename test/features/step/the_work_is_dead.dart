import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-migrate'} is dead
Future<void> theWorkIsDead(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'DEAD', running: false);
  await World.settle(tester);
}
