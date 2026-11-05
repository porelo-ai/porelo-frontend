import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: the interface says what the test machine needs to run work
///
/// Read the first time the machine is gone to and answers. A machine that lacks something says so
/// with no other action of the person's; one that lacks nothing, when asked. Either way: the verdict,
/// and each check the daemon made, in the daemon's own words.
///
/// Where the machine became the one shown when it was added, it is read there and then; where
/// another stayed shown, it is read when the person goes to it.
Future<void> theInterfaceSaysWhatTheTestMachineNeedsToRunWork(WidgetTester tester) async {
  bool shown() => find.byKey(const Key('probe')).evaluate().isNotEmpty;
  for (var waited = 0; waited < 50 && !shown(); waited++) {
    await pumpFor(tester, const Duration(milliseconds: 300));
  }
  if (!shown()) await switchTo(tester, E2e.name);
  // A machine with nothing missing says so only when asked: the first look takes the page from nobody.
  for (var waited = 0; waited < 20 && !shown(); waited++) {
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
  if (!shown()) await askWhatTheMachineCanRun(tester);
  await pumpUntil(
    tester,
    () => find.byKey(const Key('probe')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 45),
    what: 'what the machine says about itself',
  );
  // The harm: a machine that cannot run work shown as one that can. Its verdict is there, in its own place.
  expect(find.byKey(const Key('readiness-verdict')), findsOneWidget);
  expect(find.textContaining(E2e.name), findsWidgets, reason: 'the verdict must be of the test machine');
}

/// Asks through the command finder, as a person does.
Future<void> askWhatTheMachineCanRun(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpFor(tester);
  await tester.enterText(find.byKey(const Key('command-query')), 'Check whether this machine can run');
  await pumpFor(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Check whether this machine can run anything'));
  await pumpFor(tester, const Duration(milliseconds: 800));
  // The finder shows a machine's command in its menu; choosing it there is the person's act.
  await tester.tap(find.byKey(const Key('highlighted')).first);
  await pumpFor(tester);
}
