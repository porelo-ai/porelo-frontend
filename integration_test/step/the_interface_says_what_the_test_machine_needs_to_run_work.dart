import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the interface says what the test machine needs to run work
///
/// Read the first time the machine is gone to and answers, with no other action of the person's:
/// the verdict, and each check the daemon made, in the daemon's own words.
///
/// Where the machine became the one shown when it was added, it is read there and then; where
/// another stayed shown, it is read when the person goes to it.
Future<void> theInterfaceSaysWhatTheTestMachineNeedsToRunWork(WidgetTester tester) async {
  bool shown() => find.byKey(const Key('probe')).evaluate().isNotEmpty;
  for (var waited = 0; waited < 50 && !shown(); waited++) {
    await pumpFor(tester, const Duration(milliseconds: 300));
  }
  if (!shown()) await switchTo(tester, E2e.name);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('probe')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 45),
    what: 'what the machine says about itself',
  );
  // The harm: a machine that cannot run work shown as one that can. Its verdict is there, in its own place.
  expect(find.byKey(const Key('readiness-verdict')), findsOneWidget);
}
