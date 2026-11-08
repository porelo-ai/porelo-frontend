import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I grant {'jira'} from what needs a person
Future<void> iGrantFromWhatNeedsAPerson(WidgetTester tester, String entry) async {
  await expandListRows(tester);
  await World.tapInView(tester, 'grant-needed $entry');
  expect(find.byKey(const Key('grant-dialog')), findsOneWidget);
}
