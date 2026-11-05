import 'package:porelo_frontend/src/ui/small_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the log is not being followed
Future<void> theLogIsNotBeingFollowed(WidgetTester tester) async {
  // Suspending stops the view moving, never the reading — so this says nothing about whether
  // lines are still arriving, which is exactly the point of the switch.
  expect(tester.widget<SmallSwitch>(find.byKey(const Key('follow'))).value, isFalse);
}
