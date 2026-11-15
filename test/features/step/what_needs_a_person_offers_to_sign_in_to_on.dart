import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: what needs a person offers to sign in to {'Another Agent'} on {'this machine'}
Future<void> whatNeedsAPersonOffersToSignInToOn(WidgetTester tester, String agent, String machine) async {
  expect(find.text('Sign in to $agent on $machine'), findsOneWidget);
  final press = find.byKey(const Key('needs-you-sign-in'));
  expect(press, findsOneWidget, reason: 'one press from signing it in');
  await tester.ensureVisible(press);
  await tester.pump();
}
