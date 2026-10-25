import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/expand_list_rows.dart';
import '../support/e2e.dart';

/// Usage: what needs a person no longer asks for {'e2e-needed'}
Future<void> whatNeedsAPersonNoLongerAsksFor(WidgetTester tester, String entry) async {
  expect(find.textContaining('Granted. It is kept in the vault'), findsOneWidget);
  await tester.tap(find.byKey(const Key('grant-close')));
  // The machine says it is granted, whoever answered, and the question goes; only its resolved row stays.
  final question = find.byKey(ValueKey<String>('grant-needed $entry'));
  final resolved = find.descendant(of: find.byKey(const Key('recently-resolved')), matching: question);
  await pumpUntil(
    tester,
    () async {
      await expandListRows(tester);
      return question.evaluate().length == resolved.evaluate().length;
    },
    timeout: const Duration(seconds: 30),
    what: 'the question about $entry to go',
  );
}
