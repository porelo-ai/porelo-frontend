import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the Needs you row of {issue} offers to stop its work
Future<void> theNeedsYouRowOfOffersToStopItsWork(WidgetTester tester, String issue) async {
  final stop = find.byKey(Key('story-work-stop $issue'));
  expect(find.byKey(Key('story-work-stop $issue why')), findsNothing);
  expect(stop, findsOneWidget);
  expect(tester.widget<OutlinedButton>(stop).onPressed, isNotNull);
}
