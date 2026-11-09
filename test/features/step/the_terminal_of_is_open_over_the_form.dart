import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal of {'porelo-login-an-agent'} is open over the form
///
/// Attached to that login by what the machine named, run on this computer's own machine.
Future<void> theTerminalOfIsOpenOverTheForm(WidgetTester tester, String container) async {
  expect(find.byKey(const Key('unlock-cancel')), findsOneWidget, reason: 'no terminal of a sign-in is open');
  expect(World.terminals, isNotEmpty);
  expect(World.terminals.last.command, <String>['podman', 'attach', container]);
}
