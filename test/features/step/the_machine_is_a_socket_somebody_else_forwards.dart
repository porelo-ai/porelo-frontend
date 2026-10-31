import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/world.dart';

/// Usage: the machine is a socket somebody else forwards
Future<void> theMachineIsASocketSomebodyElseForwards(WidgetTester tester) async {
  // A path and no host: nothing here knows which machine is behind it.
  const machine = Machine(name: 'forwarded', socketPath: '/tmp/world-forwarded.sock');
  await World.machines.add(machine);
  World.machines.select(machine);
  // Its own page is where its commands live; the page of the machine before would refuse them.
  World.shell.openMachine(machine);
  await World.settle(tester);
}
