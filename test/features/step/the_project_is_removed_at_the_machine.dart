import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the project {'unrecorded'} is removed at the machine
///
/// By hand, where the interface cannot see it happen: nothing pushes the project list.
Future<void> theProjectIsRemovedAtTheMachine(WidgetTester tester, String project) async {
  World.backend.theProjectsItHas = World.backend.theProjectsItHas.where((each) => each.name != project).toList();
}
