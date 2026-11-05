import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the key {'SHA256:personalKeyOfThePerson'} was kept for {'ssh://git@github.com/acme/money.git'}, from {'AGENT'}
///
/// Exactly one key, for exactly the refused address: a wider match or another key forwards with one nobody chose.
Future<void> theKeyWasKeptForFrom(WidgetTester tester, String key, String address, String source) async {
  final kept = World.backend.declared.single;
  expect(kept.kind, 'SSH_KEY');
  expect(kept.match, address);
  expect(kept.id, key);
  expect(kept.source, source);
  expect(kept.purpose, 'git');
}
