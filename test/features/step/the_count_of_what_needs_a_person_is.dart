import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the count of what needs a person is {'1 need you'}
Future<void> theCountOfWhatNeedsAPersonIs(WidgetTester tester, String count) async {
  final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
  expect(badge.isLabelVisible ? '${(badge.label! as Text).data} need you' : 'nothing needs you', count);
  final subtitle = find.byKey(const Key('needs-you-subtitle'));
  if (subtitle.evaluate().isNotEmpty) {
    expect(tester.widget<Text>(subtitle).data, count == 'nothing needs you' ? 'Nothing waits on you' : count);
  }
}
