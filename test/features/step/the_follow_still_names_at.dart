import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the follow still names {'payments'} at {'git@example.org:payments.git'}
Future<void> theFollowStillNamesAt(WidgetTester tester, String name, String url) async {
  String typed(String key) => tester
      .widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)))
      .controller!
      .text;
  expect(typed('follow-name'), name);
  expect(typed('follow-url'), url);
}
