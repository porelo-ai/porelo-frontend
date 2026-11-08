import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine gives its list of projects
Future<void> theMachineGivesItsListOfProjects(WidgetTester tester) async {
  final held = World.backend.projectsHeld;
  expect(held, isNotNull, reason: 'the list of projects was not held back');
  World.backend.projectsHeld = null;
  held!.complete();
  await World.settle(tester);
}
