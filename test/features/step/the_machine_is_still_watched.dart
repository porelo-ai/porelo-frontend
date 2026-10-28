import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine {'handmade'} is still watched
Future<void> theMachineIsStillWatched(WidgetTester tester, String name) async {
  expect(World.machines.all.map((each) => each.name), contains(name));
}
