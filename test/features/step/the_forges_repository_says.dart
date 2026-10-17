import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the forge's repository {'acme/api'} says {'you are an admin'}
Future<void> theForgesRepositorySays(WidgetTester tester, String name, String words) async {
  expect(
    find.descendant(of: find.byKey(ValueKey<String>('repository $name')), matching: find.textContaining(words)),
    findsOneWidget,
  );
}
