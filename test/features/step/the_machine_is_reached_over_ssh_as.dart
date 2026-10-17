import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the machine is reached over ssh as {'alice@vm'}
Future<void> theMachineIsReachedOverSshAs(WidgetTester tester, String host) async {
  // A machine this interface raises the forward to, so it has a host to open a terminal on.
  final machine = Machine(
    name: 'vm',
    socketPath: '/tmp/world-vm.sock',
    host: host,
    remoteSocket: '/run/user/1000/porelo/porelod.sock',
  );
  await World.machines.add(machine);
  await World.settle(tester);
  // Chosen on the rail, as a person would, so its place in the tree is the one that is open.
  await tapOnScreen(tester, railEntryFor(machine.name));
  await World.settle(tester);
}
