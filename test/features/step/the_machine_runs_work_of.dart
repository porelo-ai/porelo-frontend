import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';
import 'i_watch_another_machine_called.dart';

/// Usage: the machine {'elsewhere'} runs work of {'checkout'}
///
/// The second machine the world knows, watched, with work of [project] running on it.
Future<void> theMachineRunsWorkOf(WidgetTester tester, String machine, String project) async {
  World.elsewhere.publish(<Task>[...World.elsewhere.tasksNow, World.aTask('porelo-$project-there', project)]);
  await iWatchAnotherMachineCalled(tester, machine);
}
