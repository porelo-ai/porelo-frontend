import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/new_person.dart';

/// Usage: I am offered to log in with {'Claude'}
///
/// Up to the button and not beyond: the sign-in is the person's own, in their browser.
Future<void> iAmOfferedToLogInWith(WidgetTester tester, String agent) async {
  if (!walkingAsANewPerson) return;
  final login = find.byKey(const Key('log-in-with-the-agent'));
  await pumpUntil(
    tester,
    () => login.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the offer to log in',
  );
  noteTheWindow(tester, 'the offer to log in');
  // Whatever kind of button it is drawn as: it is there, and it can be pressed.
  expect(tester.widget<ButtonStyleButton>(login).onPressed, isNotNull);
  expect(find.descendant(of: login, matching: find.textContaining(agent)), findsOneWidget);
}
