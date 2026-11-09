import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the sign-in still runs on the machine
///
/// Leaving dropped only the wait: nothing was stopped, and no second sign-in was started for it.
Future<void> theSigninStillRunsOnTheMachine(WidgetTester tester) async {
  expect(World.backend.stops, isEmpty, reason: 'leaving drops only the wait; the sign-in goes on');
  expect(World.backend.signInStarts.where((each) => each.force == true), isEmpty);
}
