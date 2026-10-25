import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I ask to remove room member {'anna'}
Future<void> iAskToRemoveRoomMember(WidgetTester tester, String person) async {
  await World.tapInView(tester, 'member-remove $person');
}
