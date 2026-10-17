import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';

import '../support/world.dart';

/// Usage: the machine {'the build machine'} answers again
///
/// **Connecting is the verdict, not the exit code.** A line that ran cleanly and left nothing
/// listening is what a missing binary looks like from here, so a start is believed only once the
/// machine answers through the same forward.
Future<void> theMachineAnswersAgain(WidgetTester tester, String name) async {
  final machine = World.machines.all.firstWhere((each) => each.name == name);
  expect(World.machines.of(machine).reachability, Reachability.connected);
}
