import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the list of work is sorted by {'Sorted by state'}
Future<void> theListOfWorkIsSortedBy(WidgetTester tester, String order) async {
  expect(
    find.descendant(of: find.byKey(const ValueKey<String>('work-list-sort')), matching: find.text(order)),
    findsOneWidget,
  );
}
