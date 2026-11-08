import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_show_the_vault.dart';

/// Usage: I grant {'jira'} from the store
Future<void> iGrantFromTheStore(WidgetTester tester, String name) async {
  await iShowTheVault(tester);
  await World.tapInView(tester, 'grant $name');
  expect(
    find.byKey(const Key('grant-dialog')),
    findsOneWidget,
    reason: 'the grant must start before its reply is sent',
  );
}
