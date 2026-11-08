import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the sign-in is waited on
Future<void> theSigninIsWaitedOn(WidgetTester tester) async {
  expect(World.backend.signInWaits, isNotEmpty);
  expect(World.backend.signInWait!.hasListener, isTrue, reason: 'nothing listens for the end of the sign-in');
}
