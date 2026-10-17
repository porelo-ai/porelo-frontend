import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing in the message can be pressed
Future<void> nothingInTheMessageCanBePressed(WidgetTester tester) async {
  final part = find.byKey(const Key('held-message-part 0'));
  // Plain data, not spans: a span is where a recognizer or a style from markup would live.
  expect(tester.widget<SelectableText>(part).textSpan, isNull);
  expect(find.descendant(of: part, matching: find.byType(InkWell)), findsNothing);
  expect(
    find.descendant(of: part, matching: find.byType(GestureDetector)).evaluate().length,
    lessThanOrEqualTo(1),
    reason: 'only the selection itself may listen',
  );
}
