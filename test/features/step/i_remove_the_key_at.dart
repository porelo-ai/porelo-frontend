import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I remove the key {'porelo old-box api/api'} at {'acme/api'}
Future<void> iRemoveTheKeyAt(WidgetTester tester, String title, String repository) async {
  final remove = find.byKey(ValueKey<String>('remove-forge-key $repository $title'));
  await tester.ensureVisible(remove);
  await tester.tap(remove);
  await World.settle(tester);
}
