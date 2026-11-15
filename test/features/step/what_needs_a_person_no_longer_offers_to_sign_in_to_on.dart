import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: what needs a person no longer offers to sign in to {'Another Agent'} on {'this machine'}
Future<void> whatNeedsAPersonNoLongerOffersToSignInToOn(WidgetTester tester, String agent, String machine) async {
  await World.settle(tester);
  expect(find.byKey(const Key('needs-you-sign-in')), findsNothing, reason: 'the machine says $agent is signed in');
  expect(find.byKey(const Key('needs-you-sign-in-panel')), findsNothing);
}
