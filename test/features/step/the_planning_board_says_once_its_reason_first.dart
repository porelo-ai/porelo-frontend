import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning board says {'porelo: no-homeserver: porelo names no homeserver'} once, its reason first
Future<void> thePlanningBoardSaysOnceItsReasonFirst(WidgetTester tester, String words) async {
  final line = find.byKey(const Key('planning-action-error'));
  expect(line, findsOneWidget);
  final shown = tester.widget<Text>(line).data ?? '';
  expect(shown, startsWith(words));
  expect(shown.substring(words.length), startsWith(' — '), reason: 'the reason stands apart from what follows it');
  expect(find.textContaining(words), findsOneWidget, reason: "said once, in the board's line alone");
}
