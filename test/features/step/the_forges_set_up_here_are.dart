import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forges set up here are {'GitHub, GitHub work'}
Future<void> theForgesSetUpHereAre(WidgetTester tester, String names) async {
  final kept = await World.forgeEntries.read();
  expect(
    <String>[
      for (final each in kept)
        if (each is Map) '${each['name']}',
    ].join(', '),
    names,
  );
}
