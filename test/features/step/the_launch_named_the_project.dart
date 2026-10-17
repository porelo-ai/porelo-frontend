import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the launch named the project {'checkout'}
Future<void> theLaunchNamedTheProject(WidgetTester tester, String name) async {
  // A name since Porelo made projects named rather than pointed at: a path on a machine this end
  // cannot see was never something a client should have had to carry.
  expect(World.backend.starts, isNotEmpty);
  expect(World.backend.starts.last.project, name);
}
