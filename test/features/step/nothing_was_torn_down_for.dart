import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing was torn down for {'elsewhere'}
Future<void> nothingWasTornDownFor(WidgetTester tester, String name) async {
  // A tunnel the interface did not raise is never torn down by it — and the way that is made
  // true is that none of it is in the map that closing walks.
  final machine = World.machines.all.firstWhere((each) => each.name == name);
  expect(World.machines.tunnels.manages(machine), isFalse);
  expect(World.forwardsAsked, isEmpty);
}
