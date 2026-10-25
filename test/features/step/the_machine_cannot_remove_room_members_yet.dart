import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine cannot remove room members yet
Future<void> theMachineCannotRemoveRoomMembersYet(WidgetTester tester) async {
  World.backend.withoutMemberRemoval = true;
}
