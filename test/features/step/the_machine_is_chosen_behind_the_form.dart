import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine {'elsewhere'} is chosen behind the form
///
/// Another machine becomes the one acted on while the start form is open, as a restart of a watched run or a
/// question about another machine chooses one.
Future<void> theMachineIsChosenBehindTheForm(WidgetTester tester, String name) async {
  World.machines.select(World.machines.all.firstWhere((each) => each.name == name));
  await World.settle(tester);
}
