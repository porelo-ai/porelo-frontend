import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I grant {'e2e-grant'} from the interface
Future<void> iGrantFromTheInterface(WidgetTester tester, String entry) async {
  await switchTo(tester, E2e.name);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpFor(tester);
  await tester.enterText(find.byType(TextField).last, 'Show the vault');
  await pumpFor(tester);
  await tester.tap(find.widgetWithText(ListTile, 'Show the vault').last);
  // The finder goes to where the action lives and marks it there; that is where it is pressed.
  final there = find.byKey(const Key('highlighted'));
  await pumpUntil(tester, () => there.evaluate().isNotEmpty, what: 'the finder to mark the store');
  await pumpFor(tester);
  await tester.tap(there.first);
  final grant = find.byKey(ValueKey<String>('grant $entry'));
  await pumpUntil(
    tester,
    () => grant.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the store listing $entry to grant',
  );
  await tester.ensureVisible(grant);
  await tester.tap(grant);
  await pumpUntilShown(tester, const Key('grant-dialog'));
}
