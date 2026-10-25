import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: the notice is resolved {'dropped 2 questions'}
Future<void> theNoticeIsResolved(WidgetTester tester, String words) async {
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  await expandListRows(tester, within: find.byKey(const Key('recently-resolved')));
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.textContaining(words)),
    findsNothing,
    reason: 'acknowledging a notice removes it from the open rows',
  );
  expect(
    find.descendant(of: find.byKey(const Key('recently-resolved')), matching: find.textContaining(words)),
    findsOneWidget,
    reason: 'the acknowledged notice remains readable in Recently resolved',
  );
}
