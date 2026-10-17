import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';

import '../support/world.dart';

/// Usage: every machine is being watched
Future<void> everyMachineIsBeingWatched(WidgetTester tester) async {
  // Not only the one being acted on. A clearance prompt has a deadline and is never asked twice,
  // so work blocked on a machine nobody is connected to expires unseen.
  expect(World.machines.all, hasLength(2));
  for (final machine in World.machines.all) {
    expect(
      World.machines.of(machine).reachability,
      Reachability.connected,
      reason: '${machine.name} is not being watched',
    );
  }
}
