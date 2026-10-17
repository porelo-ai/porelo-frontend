import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: a failed operation waits saying {'would open'}
Future<void> aFailedOperationWaitsSaying(WidgetTester tester, String words) async {
  final waiting = find.byWidgetPredicate((widget) => widget is Card && '${widget.key}'.contains("'failed-operation "));
  expect(waiting, findsWidgets, reason: 'no failed operation waits');
  expect(find.descendant(of: waiting, matching: find.textContaining(words)), findsWidgets);
}
