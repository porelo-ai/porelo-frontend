import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning board says {'porelo: no-homeserver: porelo names no homeserver'} once, its reason first
Future<void> thePlanningBoardSaysOnceItsReasonFirst(WidgetTester tester, String words) async {
  final line = find.byKey(const Key('planning-action-error'));
  expect(line, findsOneWidget);
  expect(tester.widget<Text>(line).data, startsWith(words));
  expect(find.textContaining(words), findsOneWidget, reason: "said once, in the board's line alone");
}
