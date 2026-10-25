import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: the authorization {'jira'} is resolved with its action disabled
Future<void> theAuthorizationIsResolvedWithItsActionDisabled(WidgetTester tester, String entry) async {
  await expandListRows(tester);
  final rows = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return widget is Card &&
        key is ValueKey<String> &&
        key.value.startsWith('authorization ') &&
        key.value.endsWith('/$entry');
  });
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: rows),
    findsNothing,
    reason: 'a grant confirmed by the machine must leave the open rows',
  );
  final resolved = find.descendant(of: find.byKey(const Key('recently-resolved')), matching: rows);
  expect(resolved, findsOneWidget, reason: 'the granted row remains readable in Recently resolved');
  final action = find.descendant(of: resolved, matching: find.byKey(ValueKey<String>('grant-needed $entry')));
  expect(
    tester.widget<OutlinedButton>(action).onPressed,
    isNull,
    reason: 'a resolved grant must not offer the decision again',
  );
}
