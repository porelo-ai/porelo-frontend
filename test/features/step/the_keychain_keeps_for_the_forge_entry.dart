import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the keychain keeps {'ghp_work'} for the forge entry {'GitHub work'}
Future<void> theKeychainKeepsForTheForgeEntry(WidgetTester tester, String token, String name) async {
  final kept = await World.forgeEntries.read();
  final id = <String>[
    for (final each in kept)
      if (each is Map && each['name'] == name) '${each['id']}',
  ].single;
  expect(await World.forgeTokens.read(id), token);
}
