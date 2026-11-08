import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the sign-in is no longer waited on
Future<void> theSigninIsNoLongerWaitedOn(WidgetTester tester) async {
  expect(World.backend.signInWaits, isNotEmpty, reason: 'no sign-in was waited on to begin with');
  expect(World.backend.signInWait!.hasListener, isFalse, reason: 'the wait goes on after it was left');
}
