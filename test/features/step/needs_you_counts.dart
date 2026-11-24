import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: Needs you counts {1}
///
/// Its subtitle and the badge, for rows the planner's screen draws itself as well as the window's own.
Future<void> needsYouCounts(WidgetTester tester, int count) async {
  final subtitle = find.byKey(const Key('needs-you-subtitle'));
  expect(tester.widget<Text>(subtitle).data, count == 0 ? 'Nothing waits on you' : '$count need you');
  final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
  expect(badge.isLabelVisible, count != 0);
  if (count != 0) expect((badge.label! as Text).data, '$count');
}
