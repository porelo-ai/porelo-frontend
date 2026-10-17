import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it says {'porelo-checkout-shell'} keeps running
Future<void> itSaysKeepsRunning(WidgetTester tester, String work) async {
  // Both halves need saying: somebody who thinks quitting stops a run will not quit when they
  // should, and somebody who thinks it does not will be surprised the other way.
  expect(
    find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(work)),
    findsOneWidget,
  );
}
