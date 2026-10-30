import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the follow was sent with verified project admin signers
Future<void> theFollowWasSentWithVerifiedProjectAdminSigners(WidgetTester tester) async {
  final sent = World.backend.follows.single;
  expect(sent.signers, World.following.adminSigners);
  expect(sent.signers, isNotEmpty);
  expect(sent.unverified, isNot(true));
  expect(sent.signedBy, isNull);
}
