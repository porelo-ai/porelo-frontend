import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the held saves of {'checkout'} say {'The save is not held: it runs, or was sent again.'}
Future<void> theHeldSavesOfSay(WidgetTester tester, String project, String words) async {
  final problem = find.byKey(Key('held-saves-problem $project'));
  expect(problem, findsOneWidget);
  expect(tester.widget<Text>(problem).data, words);
}
