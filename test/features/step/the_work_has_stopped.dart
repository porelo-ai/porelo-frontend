import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} has stopped
Future<void> theWorkHasStopped(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: '', running: false);
  await World.settle(tester);
}
