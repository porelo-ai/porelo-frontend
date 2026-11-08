import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the machine {'elsewhere'} is listed {false}
Future<void> theMachineIsListed(WidgetTester tester, String machine, bool listed) async {
  await toTheMachines(tester);
  expect(railEntryFor(machine).evaluate().isNotEmpty, listed);
}
