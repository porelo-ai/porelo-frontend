import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I close the terminal
Future<void> iCloseTheTerminal(WidgetTester tester) => pictured(tester, () async {
  if (Rehearsal.notRun != null) return;
  // "Close the terminal", asked first: it ends only the watching.
  await tester.tap(find.byKey(const Key('unlock-cancel')));
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('unlock-terminal')).evaluate().isEmpty,
    what: 'the terminal to close',
  );
});
