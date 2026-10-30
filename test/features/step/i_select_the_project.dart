import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I select the project {'checkout'}
Future<void> iSelectTheProject(WidgetTester tester, String project) async {
  await toTheProjects(tester);
  // The project row opens its own machine/project page.
  if (World.fleet.selectedProject?.name == project) return toTheChosenProject(tester);
  await tapOnScreen(tester, cardFor(project));
  await World.settle(tester);
}
