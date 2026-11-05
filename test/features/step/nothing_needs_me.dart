import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing needs me
Future<void> nothingNeedsMe(WidgetTester tester) async {
  // The number stands on the rail, and only there.
  expect(tester.widget<Badge>(find.byKey(const Key('needing-count-badge'))).isLabelVisible, isFalse);
}
