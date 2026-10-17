import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the menu of the repository {'payments-api'} does not say {'processes 512 (its own)'}
Future<void> theMenuOfTheRepositoryDoesNotSay(WidgetTester tester, String repository, String words) async {
  await tester.tap(find.byKey(Key('repository-menu $repository')));
  await World.settle(tester);
  expect(find.textContaining(words), findsNothing);
  await tester.tapAt(Offset.zero);
  await World.settle(tester);
}
