import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no notice says a Start was refused
Future<void> noNoticeSaysAStartWasRefused(WidgetTester tester) async {
  expect(find.byKey(const Key('planned-start-refused')), findsNothing);
}
