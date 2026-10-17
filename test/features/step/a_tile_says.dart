import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a tile says {'Cannot be reached'}
Future<void> aTileSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(Card), matching: find.textContaining(words)), findsWidgets);
}
