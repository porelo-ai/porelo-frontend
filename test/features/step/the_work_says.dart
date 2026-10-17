import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the work says {'Next: make the vault on'}
Future<void> theWorkSays(WidgetTester tester, String words) async {
  await tester.pump();
  expect(
    find.descendant(of: find.byKey(const Key('machine-area')), matching: find.textContaining(words)),
    findsWidgets,
  );
}
