import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I open the SSH Console of {'vm'}
Future<void> iOpenTheSshConsoleOf(WidgetTester tester, String machine) async {
  await openNavigationTree(tester);
  await World.tapInView(tester, 'rail ${ShellPlace.machineKey(machine)} ${MachineSection.console.name}');
  await World.tapInView(tester, 'ssh-console-open');
}
