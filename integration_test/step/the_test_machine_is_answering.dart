import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the test machine is answering
Future<void> theTestMachineIsAnswering(WidgetTester tester) async {
  await switchTo(tester, E2e.name);
  // Its own page's facts say Connected only while it answers; "Not answering" otherwise.
  await pumpUntil(
    tester,
    () => find
        .descendant(of: find.byKey(const Key('facts-page')), matching: find.text('State: Connected'))
        .evaluate()
        .isNotEmpty,
    timeout: const Duration(seconds: 45),
    what: '${E2e.name} answering',
  );
}
