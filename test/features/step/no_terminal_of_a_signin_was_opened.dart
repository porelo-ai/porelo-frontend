import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no terminal of a sign-in was opened
Future<void> noTerminalOfASigninWasOpened(WidgetTester tester) async {
  expect(
    World.terminals.where((each) => each.command.join(' ').contains('podman attach')),
    isEmpty,
    reason: 'a terminal was opened for a sign-in left',
  );
}
