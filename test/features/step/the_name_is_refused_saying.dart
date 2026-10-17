import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the name is refused saying {'cannot hold a space'}
Future<void> theNameIsRefusedSaying(WidgetTester tester, String words) async {
  expect(
    find.descendant(of: find.byKey(const Key('start-name')), matching: find.textContaining(words)),
    findsOneWidget,
  );
}
