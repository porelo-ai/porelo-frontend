import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I close the terminal of the sign-in
Future<void> iCloseTheTerminalOfTheSignin(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('login-task-terminal-close')));
  await World.settle(tester);
}
