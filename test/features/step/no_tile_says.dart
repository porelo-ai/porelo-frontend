import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no tile says {'Cannot be reached'}
Future<void> noTileSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byType(Card), matching: find.textContaining(words)), findsNothing);
}
