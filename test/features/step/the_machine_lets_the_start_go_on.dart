import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine lets the start go on
Future<void> theMachineLetsTheStartGoOn(WidgetTester tester) async {
  final held = World.backend.startHeld;
  expect(held, isNotNull, reason: 'no start was held');
  held!.complete();
  World.backend.startHeld = null;
  await World.settle(tester);
}
