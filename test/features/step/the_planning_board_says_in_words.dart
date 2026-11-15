import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning board says {'Another Agent is not signed in on this machine'} in words
Future<void> thePlanningBoardSaysInWords(WidgetTester tester, String words) async {
  final line = find.byKey(const Key('planning-action-error'));
  expect(line, findsOneWidget);
  final shown = tester.widget<Text>(line).data ?? '';
  expect(shown, contains(words));
  expect(shown, isNot(contains('org.fuin.porelo')), reason: "never the wire's type name");
  expect(shown, isNot(contains('SignInNeeded')), reason: "never the wire's type name");
}
