import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine of the form is forgotten
Future<void> theMachineOfTheFormIsForgotten(WidgetTester tester) async {
  await World.machines.forget(World.machines.all.first);
  await World.settle(tester);
}
