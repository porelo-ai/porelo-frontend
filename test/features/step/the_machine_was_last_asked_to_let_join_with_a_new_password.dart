import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine was last asked to let {'anna'} join {'checkout'} with a new password
Future<void> theMachineWasLastAskedToLetJoinWithANewPassword(WidgetTester tester, String person, String project) async {
  expect(World.backend.joins.last, (project: project, person: person, reset: true));
}
