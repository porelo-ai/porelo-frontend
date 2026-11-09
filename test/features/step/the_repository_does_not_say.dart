import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the repository {'payments-api'} does not say {'processes 512 (its own)'}
Future<void> theRepositoryDoesNotSay(WidgetTester tester, String repository, String words) async {
  await World.showRepository(tester, repository);
  expect(find.byKey(Key('repository-$repository')), findsOneWidget);
  expect(
    find.descendant(of: find.byKey(Key('repository-$repository')), matching: find.textContaining(words)),
    findsNothing,
  );
}
