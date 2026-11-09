import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I close the terminal of the sign-in
///
/// Closed while its program still runs, as a person closes it once they signed in or gave up: the terminal only.
Future<void> iCloseTheTerminalOfTheSignin(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('unlock-cancel')));
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
  await World.settle(tester);
}
