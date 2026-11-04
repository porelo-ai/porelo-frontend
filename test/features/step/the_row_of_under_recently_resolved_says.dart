import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: the row of {'porelo-checkout-shell'} under recently resolved says {'is now reachable'}
Future<void> theRowOfUnderRecentlyResolvedSays(WidgetTester tester, String work, String words) async {
  final resolved = find.byKey(const Key('recently-resolved'));
  expect(resolved, findsOneWidget);
  await expandListRows(tester, within: resolved);
  expect(find.descendant(of: resolved, matching: find.textContaining(words)), findsWidgets);
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.textContaining(work)),
    findsNothing,
    reason: 'what has come out needs nobody',
  );
}
