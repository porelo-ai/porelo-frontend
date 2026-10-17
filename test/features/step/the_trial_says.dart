import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the trial says {'Reached Porelo'}
Future<void> theTrialSays(WidgetTester tester, String words) async {
  final said = tester.widget<SelectableText>(find.byKey(const Key('trial-result'))).data;
  expect(said, contains(words));
}
