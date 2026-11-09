import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the terminal of the sign-in is on the machine its form was opened on
///
/// The form was opened on this computer's own machine: what attaches is run here, as the machine named it, and
/// never through the machine chosen meanwhile.
Future<void> theTerminalOfTheSigninIsOnTheMachineItsFormWasOpenedOn(WidgetTester tester) async {
  expect(World.terminals, isNotEmpty, reason: 'no terminal of a sign-in is open');
  expect(World.terminals.last.command, <String>['podman', 'attach', 'porelo-login-an-agent']);
  expect(World.elsewhere.signInStarts, isEmpty, reason: 'the attach must be what the form machine named');
}
