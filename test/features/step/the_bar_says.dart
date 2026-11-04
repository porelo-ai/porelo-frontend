import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the bar says {'billing'}
Future<void> theBarSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byKey(const Key('running-bar')), matching: find.textContaining(words)), findsWidgets);
}
