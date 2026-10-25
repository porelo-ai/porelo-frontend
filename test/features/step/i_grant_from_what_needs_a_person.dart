import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I grant {'jira'} from what needs a person
Future<void> iGrantFromWhatNeedsAPerson(WidgetTester tester, String entry) async {
  await expandListRows(tester);
  await tester.tap(find.byKey(ValueKey<String>('grant-needed $entry')));
  await World.settle(tester);
  expect(find.byKey(const Key('grant-dialog')), findsOneWidget);
}
