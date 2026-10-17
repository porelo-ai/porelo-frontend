import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the project header says {'worked on with Porelo’s own settings'}
Future<void> theProjectHeaderSays(WidgetTester tester, String words) async {
  expect(find.descendant(of: find.byKey(const Key('project-header')), matching: find.textContaining(words)),
      findsWidgets);
}
