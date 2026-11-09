import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no sign-in is waited on
///
/// No wait was asked, or none is listened to: no connection of this window waits on the machine.
Future<void> noSigninIsWaitedOn(WidgetTester tester) async {
  expect(World.backend.signInWait?.hasListener ?? false, isFalse, reason: 'a wait is left open on the machine');
}
