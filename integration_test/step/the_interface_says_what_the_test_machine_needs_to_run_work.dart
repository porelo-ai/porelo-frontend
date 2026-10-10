import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the interface says what the test machine needs to run work
///
/// Read the first time the machine is gone to and answers, with no other action of the person's:
/// the verdict, and each check the daemon made, in the daemon's own words.
Future<void> theInterfaceSaysWhatTheTestMachineNeedsToRunWork(WidgetTester tester) async {
  await toTheMachines(tester);
  await switchTo(tester, E2e.name);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('probe')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 45),
    what: 'what the machine says about itself',
  );
  expect(find.textContaining('This machine'), findsWidgets);
}
