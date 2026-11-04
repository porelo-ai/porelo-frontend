import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the console has a switch to follow it
Future<void> theConsoleHasASwitchToFollowIt(WidgetTester tester) async {
  expect(find.byKey(const Key('follow')), findsOneWidget);
}
