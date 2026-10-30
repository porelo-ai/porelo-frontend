import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the verified project admin signers are available
Future<void> theVerifiedProjectAdminSignersAreAvailable(WidgetTester tester) async {
  World.following.answerWith(
    () => World.following.adminSigners = const [
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    ],
  );
  await World.settle(tester);
}
