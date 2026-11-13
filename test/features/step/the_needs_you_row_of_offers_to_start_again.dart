import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the Needs you row of {issue} offers to start again
Future<void> theNeedsYouRowOfOffersToStartAgain(WidgetTester tester, String issue) async {
  final start = find.byKey(Key('story-work-start $issue'));
  expect(find.byKey(Key('story-work-start $issue why')), findsNothing);
  expect(start, findsOneWidget);
  expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
}
