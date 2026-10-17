import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'the_unlock_terminal_ends_and_is_put_away.dart';

/// Usage: the machine is asked again whether the store is open
Future<void> theMachineIsAskedAgainWhetherTheStoreIsOpen(WidgetTester tester) async {
  // The terminal's exit code is not the verdict: only the machine says whether it is open.
  expect(World.backend.storeAsked.where((each) => each == 'credentials').length, greaterThan(askedBeforeItWasPutAway));
}
