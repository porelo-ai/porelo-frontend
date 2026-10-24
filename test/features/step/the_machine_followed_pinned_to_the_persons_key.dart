import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine followed {'api'} pinned to the person's key
Future<void> theMachineFollowedPinnedToThePersonsKey(WidgetTester tester, String project) async {
  final followed = World.backend.follows.last;
  expect(followed.name, project);
  expect(followed.url, 'https://github.com/acme/api.git');
  // The key without its comment: what follow --signed-by takes.
  expect(followed.signedBy, 'ssh-ed25519 AAAAperson');
  expect(followed.unverified, isFalse);
}
