import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-billing-shell'} runs unattended
Future<void> theWorkRunsUnattended(WidgetTester tester, String work) async {
  World.theWorkIs(work, activity: 'WORKING');
  await World.settle(tester);
}
