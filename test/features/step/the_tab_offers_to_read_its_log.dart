import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tab offers to read its log
Future<void> theTabOffersToReadItsLog(WidgetTester tester) async {
  expect(find.byKey(const Key('running-read-log')), findsOneWidget);
}
