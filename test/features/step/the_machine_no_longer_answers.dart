import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';

import '../support/world.dart';

/// Usage: the machine {'the build machine'} no longer answers
///
/// **Connecting is the verdict, not the exit code**, the other way round from a start: a stop is
/// believed only once the machine no longer answers through the same forward.
Future<void> theMachineNoLongerAnswers(WidgetTester tester, String name) async {
  final machine = World.machines.all.firstWhere((each) => each.name == name);
  expect(World.machines.of(machine).reachability, isNot(Reachability.connected));
}
