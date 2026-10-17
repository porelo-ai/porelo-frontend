import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the start brings up {'porelo-checkout-schema-work'} in {'checkout'}, running {'SHELL'}
Future<void> theStartBringsUpInRunning(WidgetTester tester, String name, String project, String mode) async {
  World.backend.launch.add('container $name is up');
  World.backend.bringsUp(World.aTask(name, project, mode: mode));
  await World.backend.launch.close();
  await World.settle(tester);
  await World.settle(tester);
}
