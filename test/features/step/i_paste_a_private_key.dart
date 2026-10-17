import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I paste a private key
Future<void> iPasteAPrivateKey(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('connection-private-key')));
  await tester.enterText(
    find.byKey(const Key('connection-private-key')),
    '-----BEGIN OPENSSH PRIVATE KEY-----\npasted\n-----END OPENSSH PRIVATE KEY-----',
  );
  await World.settle(tester);
}
