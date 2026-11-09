import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/world.dart';

/// Usage: I open {'checkout'} from the projects of this machine
Future<void> iOpenFromTheProjectsOfThisMachine(WidgetTester tester, String project) async {
  final machine = World.machines.current;
  World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
  await World.settle(tester);
  await World.tapInView(tester, 'project ${machine.name}/$project');
  await World.settle(tester);
}
