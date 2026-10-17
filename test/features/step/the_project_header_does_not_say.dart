import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the project header does not say {'not followed here'}
Future<void> theProjectHeaderDoesNotSay(WidgetTester tester, String words) async {
  expect(find.byKey(const Key('project-header')), findsOneWidget);
  expect(
    find.descendant(of: find.byKey(const Key('project-header')), matching: find.textContaining(words)),
    findsNothing,
  );
}
