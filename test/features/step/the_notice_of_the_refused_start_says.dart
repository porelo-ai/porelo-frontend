import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the notice of the refused Start says {'no-homeserver'}
Future<void> theNoticeOfTheRefusedStartSays(WidgetTester tester, String words) async {
  expect(
    find.descendant(of: find.byKey(const Key('planned-start-refused')), matching: find.textContaining(words)),
    findsOneWidget,
  );
}
