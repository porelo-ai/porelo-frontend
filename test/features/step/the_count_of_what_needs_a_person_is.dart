import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the count of what needs a person is {'1 need you'}
Future<void> theCountOfWhatNeedsAPersonIs(WidgetTester tester, String count) async {
  // The number stands on the rail, and only there.
  final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
  expect(badge.isLabelVisible ? '${(badge.label! as Text).data} need you' : 'nothing needs you', count);
}
