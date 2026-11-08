import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing needs me
Future<void> nothingNeedsMe(WidgetTester tester) async {
  // A zero total hides the badge on every page.
  expect(tester.widget<Badge>(find.byKey(const Key('needing-count-badge'))).isLabelVisible, isFalse);
}
