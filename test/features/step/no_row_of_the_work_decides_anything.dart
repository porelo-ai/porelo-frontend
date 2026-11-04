import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no row of the work decides anything
Future<void> noRowOfTheWorkDecidesAnything(WidgetTester tester) async {
  expect(find.byKey(const Key('work-page')), findsOneWidget);
  for (final words in <String>['Let it through', 'Keep it blocked', 'Review at the gate', 'Got it']) {
    expect(find.text(words), findsNothing, reason: 'a row offers "$words"');
  }
}
