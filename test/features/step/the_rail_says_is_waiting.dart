import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the rail says {'1'} is waiting
Future<void> theRailSaysIsWaiting(WidgetTester tester, String count) async {
  // On the rail's Needs you, on every page, not inside a view: a question with a deadline cannot be
  // something you find only by having gone to look in the right place.
  final badge = find.byKey(const Key('needing-count-badge'));
  expect(badge, findsOneWidget);
  final shown = tester.widget<Badge>(badge);
  expect(shown.isLabelVisible, isTrue, reason: 'Needs you shows no count');
  expect((shown.label! as Text).data, count);
}
