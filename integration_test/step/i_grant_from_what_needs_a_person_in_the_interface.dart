import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I grant {'e2e-needed'} from what needs a person in the interface
Future<void> iGrantFromWhatNeedsAPersonInTheInterface(WidgetTester tester, String entry) async {
  // Where a person looks for what waits on them.
  await toThePlace(tester, 'attention');
  await pumpFor(tester);
  final grant = find.byKey(ValueKey<String>('grant-needed $entry'));
  await pumpUntil(
    tester,
    () => grant.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'what needs a person to ask for a grant of $entry',
  );
  expect(find.textContaining('Nobody has granted it yet'), findsWidgets);
  await tester.ensureVisible(grant);
  await tester.tap(grant);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('grant-link')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to answer with the page',
  );
}
