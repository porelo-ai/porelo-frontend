import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the start says {'no porelod is installed there'}
Future<void> theStartSays(WidgetTester tester, String words) async {
  expect(tester.widget<SelectableText>(find.byKey(const Key('start-result'))).data, contains(words));
}
