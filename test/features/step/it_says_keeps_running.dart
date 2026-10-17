import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it says {'porelo-checkout-shell'} keeps running
Future<void> itSaysKeepsRunning(WidgetTester tester, String work) async {
  // The harm: somebody who thinks quitting stops a run leaves work running on a machine unseen. The
  // dialog names the work and says, in a sentence of its own, that it goes on.
  final dialog = find.byType(AlertDialog);
  expect(find.descendant(of: dialog, matching: find.textContaining(work)), findsOneWidget);
  expect(find.descendant(of: dialog, matching: find.byKey(const Key('what-keeps-running'))), findsOneWidget);
}
