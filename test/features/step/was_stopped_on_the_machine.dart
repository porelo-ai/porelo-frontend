import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-shared-shell'} was stopped on the machine {'elsewhere'}
Future<void> wasStoppedOnTheMachine(WidgetTester tester, String work, String machine) async {
  expect(machine, 'elsewhere', reason: 'only the second machine records its own stops here');
  expect(World.elsewhere.stops, contains(work));
}
