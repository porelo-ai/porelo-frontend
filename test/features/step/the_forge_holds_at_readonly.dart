import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forge holds {'porelo vm api/api'} at {'acme/api'}, read-only
Future<void> theForgeHoldsAtReadonly(WidgetTester tester, String title, String repository) async {
  final held = World.forge.keysOf[repository]!.singleWhere((each) => each.title == title);
  expect(held.readOnly, isTrue);
  // The public half only: what the machine answered, never anything secret.
  expect(held.key, startsWith('ssh-ed25519 AAAAmachine-'));
}
