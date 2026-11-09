import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the repository {'payments-api'} says {'4 behind'}
Future<void> theRepositorySays(WidgetTester tester, String repository, String words) async {
  await World.showRepository(tester, repository);
  expect(
    find.descendant(of: find.byKey(Key('repository-$repository')), matching: find.textContaining(words)),
    findsOneWidget,
  );
}
