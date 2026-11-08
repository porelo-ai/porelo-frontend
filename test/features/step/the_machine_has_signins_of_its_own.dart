import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine {'elsewhere'} has sign-ins of its own
Future<void> theMachineHasSigninsOfItsOwn(WidgetTester tester, String name) async {
  expect(name, 'elsewhere');
  World.elsewhere.signsIn = true;
}
