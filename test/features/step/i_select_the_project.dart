import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I select the project {'checkout'}
Future<void> iSelectTheProject(WidgetTester tester, String project) async {
  // Default is no card on Projects any more (walk 10): its page is gone to as the finder
  // goes to it, with it selected on its machine.
  if (project == defaultProject) {
    World.fleet.selectProject(project);
    World.shell.goTo(Section.project);
    await World.settle(tester);
    return;
  }
  await toTheProjects(tester);
  // A card narrows the work to it and a second tap widens it back, so a selected one is left alone.
  if (World.fleet.selectedProject?.name == project) return toTheChosenProject(tester);
  await tapOnScreen(tester, cardFor(project));
  await World.settle(tester);
}
