import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the work does not say {'Next: make the vault'}
Future<void> theWorkDoesNotSay(WidgetTester tester, String words) async {
  await tester.pump();
  expect(
    find.descendant(of: find.byKey(const Key('machine-area')), matching: find.textContaining(words)),
    findsNothing,
  );
}
