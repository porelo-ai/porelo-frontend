import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: room member {'anna'} has left {'checkout'} at the machine
Future<void> roomMemberHasLeftAtTheMachine(WidgetTester tester, String person, String project) async {
  World.backend.membersOf[project]!.removeWhere((member) => member.person == person);
}
